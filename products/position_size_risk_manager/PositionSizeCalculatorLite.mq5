//+------------------------------------------------------------------+
//|                                   PositionSizeCalculatorLite.mq5 |
//|  Free calculator-only version of PositionSizeRiskManager: lot    |
//|  size and risk from SL, no trading. Scope: products/position_    |
//|  size_calculator_spec.md section 5c item 1.                      |
//|  Sizing logic mirrors PositionSizeRiskManager.mq5 - keep in sync.|
//+------------------------------------------------------------------+
#property copyright "Moti Botbika"
#property version   "1.00"
#property description "Free risk-based position size calculator: lot size, money at risk, SL/TP in pips, points, price and money."
#property indicator_chart_window
#property indicator_plots 0

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

input group "General"
input int            InpPointsPerPip = 0;            // Points per pip (0 = auto)
input int            InpPanelX       = 10;           // Panel X (pixels from left)
input int            InpPanelY       = 110;          // Panel Y (pixels from top; clears One Click Trading)

#define PFX "PSRL_"

ENUM_RISK_MODE g_mode;
double         g_value[3];   // value per mode: percent, money, lot
double         g_slPips;
double         g_tpPips;

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
double PipSize()
  {
   if(InpPointsPerPip > 0)
      return InpPointsPerPip * _Point;
   // Metals: a pip is conventionally 0.1 (gold) regardless of the broker's digits.
   string s = _Symbol;
   StringToUpper(s);
   if((StringFind(s, "XAU") == 0 || StringFind(s, "XAG") == 0 || StringFind(s, "GOLD") == 0) && _Point < 0.1)
      return 0.1;
   long calc = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_CALC_MODE);
   if(calc == SYMBOL_CALC_MODE_FOREX || calc == SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE)
      return (_Digits == 3 || _Digits == 5) ? _Point * 10.0 : _Point;
   // Indices, crypto, stocks and other CFDs: traders count whole price units.
   return MathMax(1.0, _Point);
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
   // An empty OBJ_LABEL renders as "Label", so blank text is a single space.
   ObjectSetString(0, n, OBJPROP_TEXT, text == "" ? " " : text);
  }

// Updates a label's text/colour without moving it.
void SetText(string name, string text, color clr = clrWhite)
  {
   ObjectSetString(0, PFX + name, OBJPROP_TEXT, text == "" ? " " : text);
   ObjectSetInteger(0, PFX + name, OBJPROP_COLOR, clr);
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
   const int x = InpPanelX, y = InpPanelY, w = 330;
   color bg = C'30,34,42', fieldBg = C'45,50,60';
   MakeBox("bg", OBJ_RECTANGLE_LABEL, x, y, w, 200, "", bg, C'70,75,85');
   MakeLabel("title", x + 10, y + 8, "Position Size Calculator Lite", 10, clrGold);
   MakeBox("mode", OBJ_BUTTON, x + 10, y + 34, 130, 22, ModeText(), fieldBg, clrWhite);
   MakeBox("value", OBJ_EDIT, x + 150, y + 34, 170, 22, ValueText(), fieldBg, clrWhite);
   MakeLabel("sl_lbl", x + 10, y + 66, "SL pips", 9, clrSilver);
   MakeBox("sl", OBJ_EDIT, x + 70, y + 64, 70, 22, DoubleToString(g_slPips, 1), fieldBg, clrWhite);
   MakeLabel("tp_lbl", x + 150, y + 66, "TP pips", 9, clrSilver);
   MakeBox("tp", OBJ_EDIT, x + 210, y + 64, 110, 22, DoubleToString(g_tpPips, 1), fieldBg, clrWhite);
   MakeLabel("lot", x + 10, y + 96, "");
   MakeLabel("risk", x + 10, y + 116, "");
   MakeLabel("slinfo", x + 10, y + 136, "", 8, clrSilver);
   MakeLabel("tpinfo", x + 10, y + 154, "", 8, clrSilver);
   MakeLabel("upsell", x + 10, y + 178, "Full version: one-click trading, breakeven, trailing, trade log", 7, C'120,160,220');
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
      SetText("lot", "Lot: -  (" + b.error + ")", clrOrange);
      SetText("risk", "");
     }
   else
     {
      SetText("lot", StringFormat("Lot  Buy %s  /  Sell %s",
                DoubleToString(b.lot, vd), DoubleToString(s.lot, vd)));
      SetText("risk", StringFormat("Risk %s %s  (%.2f%%)", DoubleToString(b.risk, 2), cur,
                bal > 0 ? b.risk / bal * 100.0 : 0.0));
     }
   SetText("slinfo", StringFormat("SL %.1f pips | %.0f pts | buy %s / sell %s",
             g_slPips, pts, DoubleToString(b.sl, _Digits), DoubleToString(s.sl, _Digits)), clrSilver);
   if(g_tpPips > 0)
      SetText("tpinfo", StringFormat("TP %.1f pips | +%s %s | R:R 1:%.2f", g_tpPips,
                DoubleToString(b.reward, 2), cur, g_slPips > 0 ? g_tpPips / g_slPips : 0.0), clrSilver);
   else
      SetText("tpinfo", "TP none", clrSilver);
   ChartRedraw();
  }

double ReadEdit(string name, double fallback, double minValue)
  {
   double v = StringToDouble(ObjectGetString(0, PFX + name, OBJPROP_TEXT));
   return (v >= minValue) ? v : fallback;
  }

//+------------------------------------------------------------------+
//| Indicator events                                                 |
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

   BuildPanel();
   UpdatePanel();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, PFX);
   ChartRedraw();
  }

int OnCalculate(const int rates_total, const int prev_calculated, const int begin, const double &price[])
  {
   UpdatePanel();
   return rates_total;
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == PFX + "mode")
     {
      g_mode = (ENUM_RISK_MODE)(((int)g_mode + 1) % 3);
      ObjectSetString(0, PFX + "mode", OBJPROP_TEXT, ModeText());
      ObjectSetString(0, PFX + "value", OBJPROP_TEXT, ValueText());
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
