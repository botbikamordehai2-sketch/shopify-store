# Position Size & Risk Manager (MT5 EA)

v1 build of the product specified in
[`../position_size_calculator_spec.md`](../position_size_calculator_spec.md) §4.
Sold on the MQL5 Market (category: Utilities), not through Shopify.

**Status:** compiles in MetaEditor (0 errors, 0 warnings). Strategy Tester
passed on EURUSD, USDJPY, XAUUSD and US30 (see *Tester results* below).
Live demo check 2026-10-02 (MetaQuotes-Demo, EURUSD): panel shows correct lot
and risk, mode button cycles, BUY opened 0.10 lots with SL 20 / TP 40 pips.
Breakeven/trailing/CSV on a live demo trade not yet observed. Nothing has been
submitted to the MQL5 Market.

The panel sits at *Panel X / Panel Y* (default 10, 110) so it clears MT5's own
One Click Trading panel in the chart corner.

## Free Lite version

`PositionSizeCalculatorLite.mq5` is a separate **indicator** (category:
Indicators, price: free) with the calculator panel only — risk modes, SL/TP
in pips, lot and money at risk, SL/TP prices, R:R. No Buy/Sell buttons, no
breakeven/trailing, no trade log; a line on the panel points to the full
version. Being an indicator, it cannot trade and needs no Algo Trading
permission. Its sizing code is a copy of the EA's — change both together.
Install it under `MQL5\Indicators\PSRM\` and attach from Navigator →
Indicators → PSRM. Compiles with 0 errors / 0 warnings; not yet checked on a
chart.

## Install for testing

1. Copy `PositionSizeRiskManager.mq5` to
   `<MT5 data folder>\MQL5\Experts\PSRM\` (File → Open Data Folder).
2. Open it in MetaEditor and press Compile (F7).
3. In MT5, enable **Algo Trading**, then drag the EA onto a chart.

## What it does

| Feature | How |
|---|---|
| Lot size from risk | Mode button cycles **Risk %** (of balance) → **Risk $** (fixed amount) → **Fixed lot** (shows the resulting risk). Lot is rounded *down* to the symbol's volume step, so risk is never exceeded. Uses `OrderCalcProfit`, so it is correct for forex, JPY pairs, metals and indices. |
| SL / TP | Entered in pips on the panel; shown in pips, points, price and money, with R:R. TP 0 = none. |
| Buy / Sell | Opens at market with the calculated lot, SL and TP. Checks trading session, algo-trading permission, symbol trade mode, stops level, SL beyond the spread, and free margin first. |
| Breakeven | Once profit ≥ trigger pips, SL moves to entry + offset pips. |
| Trailing stop | Once profit ≥ trailing distance, SL trails at that distance, moving only in steps of *step* pips. |
| Trade log | Every closed trade opened by this EA is appended to `MQL5\Files\PSRM_trade_log.csv`: open time, symbol, direction, entry, SL, TP, lots, risk, close time, close price, profit, swap, commission. |

What one pip means (auto; override with *Points per pip*):

- Forex: 10 points on 3/5-digit quotes (0.0001, or 0.01 on JPY pairs), else 1 point.
- Metals (XAU/XAG/GOLD): 0.1.
- Everything else (indices, crypto, stocks, other CFDs): 1.0 price unit.

The panel always shows points and price too, so the pip convention is visible.

## Tester results (2026-10-02, MetaQuotes-Demo, H1, 2026.06.01–09.30)

Settings: balance 10,000 USD, risk 1%, SL 20 pips, TP 40, breakeven 15/1,
trailing 20/5, demo trades on. Zero order or SL-modify errors on every symbol.

| Symbol | Trades logged | Sample lot (risk) | Expected |
|---|---|---|---|
| EURUSD | 176 | 0.49 (98.00 USD) | 0.50 at full balance ✓ |
| USDJPY | 464 | 0.79 (99.25 USD) at 159.40 | 100 / (20 × 1000/159.4) = 0.797 → 0.79 ✓ |
| XAUUSD | 1908 | 0.49 (98.00 USD), SL 2.00 | 98 / 200 = 0.49 ✓ |
| US30 | 1814 | 5.0 (100.00 USD), SL 20 points | ✓ |

Breakeven exits show as +1 pip closes (e.g. EURUSD +4.90 on 0.49 lots) and
trailing exits as larger partial-run profits, so both fire. On US30 the EA
correctly refused trades when free margin was too low and outside the
trading session. The P&L of these runs is meaningless — demo trades just
alternate buy/sell to exercise the code.

## Demo-account test checklist

Run on a **demo** account. For each step, compare with the expected result.

1. **Lot, Risk % mode** — EURUSD, balance 10,000, risk 1%, SL 20 pips.
   Expected: risk ≈ 100 USD, lot = 0.50 (EURUSD ≈ $10/pip per lot → 100 / (20 × 10)).
2. **Lot, USDJPY** — same settings. Expected lot ≈ 100 / (20 × pip value);
   pip value per lot ≈ 1000 / USDJPY rate in USD (≈ $6.67 at 150) → ≈ 0.75.
3. **Lot, XAUUSD** — risk $100, SL 20 pips (= 2.00 price move).
   Contract 100 oz → $200 loss per lot → lot 0.50. Check your broker's
   contract size in the symbol specification; it changes the answer.
4. **Fixed lot mode** — set 0.10; panel must show the money and % at risk.
5. **Too-small risk** — risk $0.01. Expected: "Lot below symbol minimum",
   BUY/SELL do nothing.
6. **Buy / Sell** — click each; position opens with the panel's lot, SL, TP.
7. **Algo Trading off** — click BUY; status shows "Algo trading is disabled".
8. **Breakeven** — trigger 15, offset 1; when the trade is +15 pips, SL jumps
   to entry +1 pip (buy) / −1 pip (sell).
9. **Trailing** — distance 20, step 5; at +20 pips SL starts following,
   moving only in 5-pip steps, never backwards.
10. **Trade log** — close a trade; open `MQL5\Files\PSRM_trade_log.csv`
    (File → Open Data Folder) and check the row matches the trade.
11. **Strategy Tester** — run on EURUSD and XAUUSD, any timeframe, "Every
    tick". With *Strategy Tester: open demo trades* on, it should open and
    close trades with no errors in the Journal (this mimics the MQL5 Market
    automatic validation, which has no user to click the panel).
12. **Remove EA** — all panel objects disappear from the chart.
