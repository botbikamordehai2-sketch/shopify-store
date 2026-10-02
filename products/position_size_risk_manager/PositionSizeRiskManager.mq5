//+------------------------------------------------------------------+
//|                                     PositionSizeRiskManager.mq5  |
//|  Trade panel: risk-based lot size, SL/TP, breakeven, trailing,   |
//|  and a CSV trade log. Scope: products/position_size_calculator_  |
//|  spec.md section 4 (v1).                                         |
//+------------------------------------------------------------------+
#property copyright "Moti Botbika"
#property version   "1.00"
#property description "Risk-based position sizing panel with SL/TP, breakeven, trailing stop and CSV trade log."

#include <Trade\Trade.mqh>

enum ENUM_RISK_MODE
  {
   RISK_PERCENT = 0, // % of balance
   RISK_MONEY   = 1, // Fixed amount (account currency)
   RISK_FIXED_LOT = 2 // Fixed lot (shows resulting risk)
  };

input group "Risk"
input ENUM_RISK_MODE InpRiskMode     = RISK_PERCENT; // Risk mode
input double         InpRiskPercent  = 1.0;          // Risk % of balance
input double         InpRiskMoney    = 100.0;        // Risk amount (account currency)
input double         InpFixedLot     = 0.10;         // Fixed lot
input double         InpSLPips       = 20.0;         // Stop loss (pips)
input double         InpTPPips       = 40.0;         // Take profit (pips, 0 = none)

input group "Trade management"
input double         InpBETriggerPips  = 15.0;       // Breakeven trigger (pips, 0 = off)
input double         InpBEOffsetPips   = 1.0;        // Breakeven offset (pips)
input double         InpTrailPips      = 20.0;       // Trailing distance (pips, 0 = off)
input double         InpTrailStepPips  = 5.0;        // Trailing step (pips)

input group "General"
input long           InpMagic          = 20261002;   // Magic number
input int            InpSlippagePoints = 10;         // Max slippage (points)
input string         InpLogFile        = "PSRM_trade_log.csv"; // Trade log file (MQL5\Files)
input bool           InpTesterDemo     = true;       // Strategy Tester: open demo trades

#define PFX "PSRM_"

CTrade         g_trade;
ENUM_RISK_MODE g_mode;
double         g_value[3];   // value per mode: percent, money, lot
double         g_slPips;
double         g_tpPips;
string         g_status = "";
datetime       g_lastBar = 0;
bool           g_demoBuy = true;

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
double PipSize()
  {
   return (_Digits == 3 || _Digits == 5) ? _Point * 10.0 : _Point;
  }

double NormPrice(double price)
  {
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ts > 0)
      price = MathRound(price / ts) * ts;
   return NormalizeDouble(price, _Digits);
  }

int VolumeDigits()
  {
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0)
      return 2;
   return (int)MathMax(0, MathCeil(-MathLog10(step) - 1e-9));
  }

// Rounds DOWN to the volume step so risk is never exceeded. Returns 0 if below the minimum.
double NormVolumeDown(double vol)
  {
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vlim = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
   if(step <= 0)
      step = 0.01;
   vol = MathFloor(vol / step + 1e-7) * step;
   if(vol < vmin)
      return 0.0;
   if(vmax > 0)
      vol = MathMin(vol, vmax);
   if(vlim > 0)
      vol = MathMin(vol, vlim);
   return NormalizeDouble(vol, VolumeDigits());
  }

// Money lost on `lots` if price goes from entry to sl. Returns -1 on failure.
double LossMoney(bool isBuy, double lots, double entry, double sl)
  {
   double profit = 0.0;
   ENUM_ORDER_TYPE type = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcProfit(type, _Symbol, lots, entry, sl, profit))
      return -1.0;
   return MathAbs(profit);
  }

struct SizeResult
  {
   double            entry;
   double            sl;
   double            tp;
   double            lot;
   double            risk;     // money at risk with `lot`
   double            reward;   // money gained at TP with `lot`
   string            error;
  };

SizeResult CalcSize(bool isBuy)
  {
   SizeResult r;
   r.lot = 0;
   r.risk = 0;
   r.reward = 0;
   r.error = "";
   double pip = PipSize();
   r.entry = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   r.sl = NormPrice(isBuy ? r.entry - g_slPips * pip : r.entry + g_slPips * pip);
   r.tp = (g_tpPips > 0) ? NormPrice(isBuy ? r.entry + g_tpPips * pip : r.entry - g_tpPips * pip) : 0.0;
   if(r.entry <= 0)
     {
      r.error = "No price";
      return r;
     }

   double lossPerLot = LossMoney(isBuy, 1.0, r.entry, r.sl);
   if(lossPerLot <= 0)
     {
      r.error = "Cannot price SL";
      return r;
     }

   if(g_mode == RISK_FIXED_LOT)
      r.lot = NormVolumeDown(g_value[RISK_FIXED_LOT]);
   else
     {
      double riskMoney = (g_mode == RISK_PERCENT)
                         ? AccountInfoDouble(ACCOUNT_BALANCE) * g_value[RISK_PERCENT] / 100.0
                         : g_value[RISK_MONEY];
      r.lot = NormVolumeDown(riskMoney / lossPerLot);
     }
   if(r.lot <= 0)
     {
      r.error = "Lot below symbol minimum";
      return r;
     }
   r.risk = LossMoney(isBuy, r.lot, r.entry, r.sl);
   if(r.tp > 0)
      r.reward = LossMoney(isBuy, r.lot, r.entry, r.tp);
   return r;
  }

//+------------------------------------------------------------------+
//| Pre-trade checks (MQL5 Market requirements)                      |
//+------------------------------------------------------------------+
bool CanTrade(bool isBuy, const SizeResult &r, string &why)
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      why = "Algo trading is disabled";
      return false;
     }
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
     {
      why = "Trading not allowed on this account";
      return false;
     }
   long mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(mode == SYMBOL_TRADE_MODE_DISABLED || mode == SYMBOL_TRADE_MODE_CLOSEONLY ||
      (isBuy && mode == SYMBOL_TRADE_MODE_SHORTONLY) || (!isBuy && mode == SYMBOL_TRADE_MODE_LONGONLY))
     {
      why = "Symbol does not allow this trade";
      return false;
     }
   if(r.error != "")
     {
      why = r.error;
      return false;
     }
   double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(MathAbs(r.entry - r.sl) < minDist || (r.tp > 0 && MathAbs(r.tp - r.entry) < minDist))
     {
      why = "SL/TP closer than broker stops level";
      return false;
     }
   double margin = 0.0;
   ENUM_ORDER_TYPE type = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcMargin(type, _Symbol, r.lot, r.entry, margin))
     {
      why = "Cannot calculate margin";
      return false;
     }
   if(margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
     {
      why = "Not enough free margin";
      return false;
     }
   return true;
  }

bool OpenTrade(bool isBuy, bool allowMinLot = false)
  {
   SizeResult r = CalcSize(isBuy);
   if(allowMinLot && r.lot <= 0 && r.error == "Lot below symbol minimum")
     {
      r.lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      r.error = "";
     }
   string why = "";
   if(!CanTrade(isBuy, r, why))
     {
      g_status = why;
      return false;
     }
   bool ok = isBuy ? g_trade.Buy(r.lot, _Symbol, 0.0, r.sl, r.tp, "PSRM")
                   : g_trade.Sell(r.lot, _Symbol, 0.0, r.sl, r.tp, "PSRM");
   uint rc = g_trade.ResultRetcode();
   if(!ok || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_PLACED))
     {
      g_status = StringFormat("Order failed: %u %s", rc, g_trade.ResultRetcodeDescription());
      Print(g_status);
      return false;
     }
   g_status = StringFormat("%s %s lots opened", isBuy ? "BUY" : "SELL",
                           DoubleToString(r.lot, VolumeDigits()));
   return true;
  }

//+------------------------------------------------------------------+
//| Breakeven + trailing stop                                        |
//+------------------------------------------------------------------+
void ManagePositions()
  {
   if(InpBETriggerPips <= 0 && InpTrailPips <= 0)
      return;
   double pip = PipSize();
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double minDist = (double)MathMax(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
                                    SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL)) * _Point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;

      bool   isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double open  = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);
      double newSL = sl;

      if(isBuy)
        {
         double profitPips = (bid - open) / pip;
         if(InpBETriggerPips > 0 && profitPips >= InpBETriggerPips)
            newSL = MathMax(newSL, open + InpBEOffsetPips * pip);
         if(InpTrailPips > 0 && profitPips >= InpTrailPips)
           {
            double t = bid - InpTrailPips * pip;
            if(t >= newSL + InpTrailStepPips * pip)
               newSL = t;
           }
         newSL = NormPrice(newSL);
         if(newSL <= sl + _Point / 2 || bid - newSL < minDist)
            continue;
        }
      else
        {
         double cur = (sl == 0.0) ? DBL_MAX : sl;
         double profitPips = (open - ask) / pip;
         newSL = cur;
         if(InpBETriggerPips > 0 && profitPips >= InpBETriggerPips)
            newSL = MathMin(newSL, open - InpBEOffsetPips * pip);
         if(InpTrailPips > 0 && profitPips >= InpTrailPips)
           {
            double t = ask + InpTrailPips * pip;
            if(t <= newSL - InpTrailStepPips * pip)
               newSL = t;
           }
         if(newSL == DBL_MAX)
            continue;
         newSL = NormPrice(newSL);
         if(newSL >= cur - _Point / 2 || newSL - ask < minDist)
            continue;
        }

      if(!g_trade.PositionModify(ticket, newSL, tp))
         Print("SL modify failed: ", g_trade.ResultRetcode(), " ", g_trade.ResultRetcodeDescription());
     }
  }

//+------------------------------------------------------------------+
//| CSV trade log                                                    |
//+------------------------------------------------------------------+
void LogClosedDeal(ulong closeDeal)
  {
   if(!HistoryDealSelect(closeDeal))
      return;
   long entryType = HistoryDealGetInteger(closeDeal, DEAL_ENTRY);
   if(entryType != DEAL_ENTRY_OUT && entryType != DEAL_ENTRY_OUT_BY)
      return;
   long     posId      = HistoryDealGetInteger(closeDeal, DEAL_POSITION_ID);
   datetime closeTime  = (datetime)HistoryDealGetInteger(closeDeal, DEAL_TIME);
   double   closePrice = HistoryDealGetDouble(closeDeal, DEAL_PRICE);
   double   volume     = HistoryDealGetDouble(closeDeal, DEAL_VOLUME);
   double   profit     = HistoryDealGetDouble(closeDeal, DEAL_PROFIT);
   double   swap       = HistoryDealGetDouble(closeDeal, DEAL_SWAP);
   double   commission = HistoryDealGetDouble(closeDeal, DEAL_COMMISSION);

   if(!HistorySelectByPosition(posId))
      return;
   ulong inDeal = 0;
   for(int i = 0; i < HistoryDealsTotal(); i++)
     {
      ulong d = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN)
        {
         inDeal = d;
         break;
        }
     }
   if(inDeal == 0 || HistoryDealGetInteger(inDeal, DEAL_MAGIC) != InpMagic ||
      HistoryDealGetString(inDeal, DEAL_SYMBOL) != _Symbol)
      return;

   bool     isBuy    = (HistoryDealGetInteger(inDeal, DEAL_TYPE) == DEAL_TYPE_BUY);
   datetime openTime = (datetime)HistoryDealGetInteger(inDeal, DEAL_TIME);
   double   entry    = HistoryDealGetDouble(inDeal, DEAL_PRICE);
   double   sl       = HistoryDealGetDouble(inDeal, DEAL_SL);
   double   tp       = HistoryDealGetDouble(inDeal, DEAL_TP);
   double   risk     = (sl > 0) ? LossMoney(isBuy, volume, entry, sl) : 0.0;

   int h = FileOpen(InpLogFile, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
   if(h == INVALID_HANDLE)
     {
      Print("Cannot open trade log ", InpLogFile, ": ", GetLastError());
      return;
     }
   if(FileSize(h) == 0)
      FileWrite(h, "open_time", "symbol", "direction", "entry", "sl", "tp", "lots",
                "risk", "close_time", "close_price", "profit", "swap", "commission");
   FileSeek(h, 0, SEEK_END);
   FileWrite(h,
             TimeToString(openTime, TIME_DATE | TIME_SECONDS), _Symbol, isBuy ? "BUY" : "SELL",
             DoubleToString(entry, _Digits), DoubleToString(sl, _Digits), DoubleToString(tp, _Digits),
             DoubleToString(volume, VolumeDigits()), DoubleToString(risk, 2),
             TimeToString(closeTime, TIME_DATE | TIME_SECONDS), DoubleToString(closePrice, _Digits),
             DoubleToString(profit, 2), DoubleToString(swap, 2), DoubleToString(commission, 2));
   FileClose(h);
  }

//+------------------------------------------------------------------+
//| Panel                                                            |
//+------------------------------------------------------------------+
void MakeLabel(string name, int x, int y, string text, int size = 9, color clr = clrWhite)
  {
   string n = PFX + name;
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, n, OBJPROP_FONT, "Segoe UI");
     }
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetString(0, n, OBJPROP_TEXT, text);
  }

void MakeBox(string name, ENUM_OBJECT type, int x, int y, int w, int h, string text, color bg, color fg)
  {
   string n = PFX + name;
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, type, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, n, OBJPROP_FONT, "Segoe UI");
      ObjectSetInteger(0, n, OBJPROP_FONTSIZE, 9);
     }
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_COLOR, fg);
   if(type != OBJ_RECTANGLE_LABEL)
      ObjectSetString(0, n, OBJPROP_TEXT, text);
   if(type == OBJ_EDIT)
      ObjectSetInteger(0, n, OBJPROP_ALIGN, ALIGN_RIGHT);
  }

string ModeText()
  {
   if(g_mode == RISK_PERCENT)
      return "Risk %";
   if(g_mode == RISK_MONEY)
      return "Risk " + AccountInfoString(ACCOUNT_CURRENCY);
   return "Fixed lot";
  }

string ValueText()
  {
   int digits = (g_mode == RISK_FIXED_LOT) ? VolumeDigits() : 2;
   return DoubleToString(g_value[g_mode], digits);
  }

void BuildPanel()
  {
   const int x = 10, y = 25, w = 290;
   color bg = C'30,34,42', fieldBg = C'45,50,60';
   MakeBox("bg", OBJ_RECTANGLE_LABEL, x, y, w, 232, "", bg, C'70,75,85');
   MakeLabel("title", x + 10, y + 8, "Position Size & Risk", 10, clrGold);
   MakeBox("mode", OBJ_BUTTON, x + 10, y + 34, 130, 22, ModeText(), fieldBg, clrWhite);
   MakeBox("value", OBJ_EDIT, x + 150, y + 34, 130, 22, ValueText(), fieldBg, clrWhite);
   MakeLabel("sl_lbl", x + 10, y + 66, "SL pips", 9, clrSilver);
   MakeBox("sl", OBJ_EDIT, x + 70, y + 64, 70, 22, DoubleToString(g_slPips, 1), fieldBg, clrWhite);
   MakeLabel("tp_lbl", x + 150, y + 66, "TP pips", 9, clrSilver);
   MakeBox("tp", OBJ_EDIT, x + 210, y + 64, 70, 22, DoubleToString(g_tpPips, 1), fieldBg, clrWhite);
   MakeLabel("lot", x + 10, y + 96, "");
   MakeLabel("risk", x + 10, y + 116, "");
   MakeLabel("slinfo", x + 10, y + 136, "", 8, clrSilver);
   MakeLabel("tpinfo", x + 10, y + 154, "", 8, clrSilver);
   MakeBox("buy", OBJ_BUTTON, x + 10, y + 176, 130, 26, "BUY", C'0,120,80', clrWhite);
   MakeBox("sell", OBJ_BUTTON, x + 150, y + 176, 130, 26, "SELL", C'170,40,40', clrWhite);
   MakeLabel("status", x + 10, y + 208, "", 8, clrSilver);
  }

void UpdatePanel()
  {
   SizeResult b = CalcSize(true);
   SizeResult s = CalcSize(false);
   string cur = AccountInfoString(ACCOUNT_CURRENCY);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   int vd = VolumeDigits();
   double pts = g_slPips * PipSize() / _Point;

   if(b.error != "")
     {
      MakeLabel("lot", 20, 121, "Lot: -  (" + b.error + ")", 9, clrOrange);
      MakeLabel("risk", 20, 141, "");
     }
   else
     {
      MakeLabel("lot", 20, 121, StringFormat("Lot  Buy %s  /  Sell %s",
                DoubleToString(b.lot, vd), DoubleToString(s.lot, vd)));
      MakeLabel("risk", 20, 141, StringFormat("Risk %s %s  (%.2f%%)", DoubleToString(b.risk, 2), cur,
                bal > 0 ? b.risk / bal * 100.0 : 0.0));
     }
   MakeLabel("slinfo", 20, 161, StringFormat("SL %.1f pips | %.0f pts | buy %s / sell %s",
             g_slPips, pts, DoubleToString(b.sl, _Digits), DoubleToString(s.sl, _Digits)), 8, clrSilver);
   if(g_tpPips > 0)
      MakeLabel("tpinfo", 20, 179, StringFormat("TP %.1f pips | +%s %s | R:R 1:%.2f", g_tpPips,
                DoubleToString(b.reward, 2), cur, g_slPips > 0 ? g_tpPips / g_slPips : 0.0), 8, clrSilver);
   else
      MakeLabel("tpinfo", 20, 179, "TP none", 8, clrSilver);
   MakeLabel("status", 20, 233, g_status, 8, clrSilver);
   ChartRedraw();
  }

double ReadEdit(string name, double fallback, double minValue)
  {
   double v = StringToDouble(ObjectGetString(0, PFX + name, OBJPROP_TEXT));
   return (v >= minValue) ? v : fallback;
  }

//+------------------------------------------------------------------+
//| Expert events                                                    |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpSLPips <= 0 || InpTPPips < 0 || InpRiskPercent <= 0 || InpRiskMoney <= 0 || InpFixedLot <= 0)
     {
      Print("Invalid inputs: SL, risk %, risk amount and fixed lot must be > 0; TP must be >= 0");
      return INIT_PARAMETERS_INCORRECT;
     }
   g_mode = InpRiskMode;
   g_value[RISK_PERCENT] = InpRiskPercent;
   g_value[RISK_MONEY] = InpRiskMoney;
   g_value[RISK_FIXED_LOT] = InpFixedLot;
   g_slPips = InpSLPips;
   g_tpPips = InpTPPips;

   g_trade.SetExpertMagicNumber((ulong)InpMagic);
   g_trade.SetDeviationInPoints(InpSlippagePoints);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.LogLevel(LOG_LEVEL_ERRORS);

   BuildPanel();
   UpdatePanel();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, PFX);
   ChartRedraw();
  }

void OnTick()
  {
   ManagePositions();

   // Strategy Tester has no user to click the panel: open demo trades one bar at a time.
   if(InpTesterDemo && MQLInfoInteger(MQL_TESTER))
     {
      datetime bar = iTime(_Symbol, _Period, 0);
      if(bar != g_lastBar)
        {
         g_lastBar = bar;
         bool hasPos = false;
         for(int i = PositionsTotal() - 1; i >= 0 && !hasPos; i--)
            if(PositionGetTicket(i) > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == InpMagic)
               hasPos = true;
         if(!hasPos && OpenTrade(g_demoBuy, true))
            g_demoBuy = !g_demoBuy;
        }
     }
   UpdatePanel();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
      LogClosedDeal(trans.deal);
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == PFX + "mode")
        {
         g_mode = (ENUM_RISK_MODE)(((int)g_mode + 1) % 3);
         ObjectSetString(0, PFX + "mode", OBJPROP_TEXT, ModeText());
         ObjectSetString(0, PFX + "value", OBJPROP_TEXT, ValueText());
        }
      else
         if(sparam == PFX + "buy" || sparam == PFX + "sell")
           {
            OpenTrade(sparam == PFX + "buy");
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
           }
      ObjectSetInteger(0, PFX + "mode", OBJPROP_STATE, false);
      UpdatePanel();
     }
   else
      if(id == CHARTEVENT_OBJECT_ENDEDIT)
        {
         if(sparam == PFX + "value")
           {
            g_value[g_mode] = ReadEdit("value", g_value[g_mode], 0.000001);
            ObjectSetString(0, sparam, OBJPROP_TEXT, ValueText());
           }
         else
            if(sparam == PFX + "sl")
              {
               g_slPips = ReadEdit("sl", g_slPips, 0.1);
               ObjectSetString(0, sparam, OBJPROP_TEXT, DoubleToString(g_slPips, 1));
              }
            else
               if(sparam == PFX + "tp")
                 {
                  g_tpPips = ReadEdit("tp", g_tpPips, 0.0);
                  ObjectSetString(0, sparam, OBJPROP_TEXT, DoubleToString(g_tpPips, 1));
                 }
         UpdatePanel();
        }
  }
//+------------------------------------------------------------------+
