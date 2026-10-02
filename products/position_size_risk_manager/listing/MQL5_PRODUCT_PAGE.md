# MQL5 Market listing — DRAFT

**Status:** DRAFT for Moti's review. Nothing here is uploaded or published.
Only Moti uploads to the MQL5 Market, after approving this text.

Rules for every line below: no profit promises, no win-rate or "never
lose" claims. The product controls *risk*, not *direction*.

---

## A. Paid product — Position Size & Risk Manager (MT5)

| Field | Value |
|---|---|
| Category | Utilities |
| Platform | MetaTrader 5 |
| File | `PositionSizeRiskManager.ex5` |
| Price | $39 launch, then $68 |
| Activations | 20 |
| Free demo | Automatic (MQL5 Strategy Tester demo) |

### Title
Position Size and Risk Manager MT5

### Short description (one line)
Know exactly how much you risk before every trade: risk-based lot size,
one-click orders with SL/TP, breakeven, trailing stop and a CSV trade log.

### Full description

**Position Size & Risk Manager** calculates the correct lot size for every
trade from the amount you are willing to lose, and places the trade with
the stop loss and take profit already set.

It does not decide when to buy or sell. You decide the trade — the panel
makes sure that if the trade fails, you lose exactly the amount you chose,
and not a cent more.

**What you get**

- **Risk-based lot size** in three modes — switch with one click:
  - Risk % of balance (e.g. 1%)
  - Fixed amount in your account currency (e.g. $100)
  - Fixed lot (the panel shows how much that lot risks)
- **Works beyond forex** — tested on forex, JPY pairs, gold and indices.
  The lot is calculated from the broker's own contract data (so it also
  applies to crypto and other CFDs), and always rounded **down**, so the
  real risk never exceeds the risk you set.
- **SL and TP in pips**, shown at the same time in points, price and money,
  with the reward-to-risk ratio.
- **One-click BUY / SELL** with the calculated lot, SL and TP.
- **Breakeven** — moves the stop loss to entry (plus an offset) once the
  trade is in profit by the distance you set.
- **Trailing stop** — follows price at a set distance, moving in steps,
  never backwards.
- **Trade log** — every closed trade opened from the panel is saved to a
  CSV file (open/close time, direction, entry, SL, TP, lots, money at
  risk, close price, profit, swap, commission). Open it in Excel or Google
  Sheets to review your trading.
- **20 activations** — use it on your home PC, laptop and VPS.

**Safety checks before every order**

The panel will not send an order when the market is closed, when algo
trading is off, when free margin is too low, when the stop loss is
inside the spread or closer than the broker allows, or when the risk you
set is smaller than the symbol's minimum lot. It tells you why on the
panel instead.

**How to use**

1. Attach the EA to a chart and allow Algo Trading.
2. Choose the risk mode and value (for example *Risk %* and *1.00*).
3. Enter the stop loss and take profit in pips.
4. Read the lot size and money at risk on the panel.
5. Click BUY or SELL.

**Inputs**

| Input | Default | Meaning |
|---|---|---|
| Risk mode | % of balance | % / fixed amount / fixed lot |
| Risk % of balance | 1.0 | |
| Risk amount | 100 | In account currency |
| Fixed lot | 0.10 | |
| Stop loss (pips) | 20 | |
| Take profit (pips) | 40 | 0 = no TP |
| Breakeven trigger / offset | 15 / 1 | 0 = off |
| Trailing distance / step | 20 / 5 | 0 = off |
| Points per pip | 0 (auto) | Override the pip definition |
| Magic number | 20261002 | Identifies the EA's trades |
| Max slippage (points) | 10 | |
| Trade log file | PSRM_trade_log.csv | Saved in MQL5\Files |
| Panel X / Y | 10 / 110 | Clears MT5's One Click Trading panel |

**What counts as a pip:** forex 0.0001 (0.01 on JPY pairs), gold and
silver 0.1, indices/crypto/stocks 1.0. The panel always shows points and
price too, and you can override it with *Points per pip*.

**Important:** trading involves risk of loss. This tool manages position
size and stop placement; it does not predict the market and does not
guarantee profit.

**Support:** send me a private message on MQL5 — I answer every message.

### Screenshots to capture (Moti, from the demo account)

1. Panel on EURUSD in *Risk %* mode — lot and money at risk visible.
2. Same panel in *Fixed lot* mode.
3. A trade just opened: SL and TP lines on the chart + the Trade tab.
4. Panel on XAUUSD (gold) — shows it works beyond forex.
5. The trade log CSV opened in Excel.
6. The inputs window.

Tip: hide MT5's own One Click Trading panel first (click the chart, Alt+T).

### ~1-minute video outline

| Time | Show | Say (caption) |
|---|---|---|
| 0–10s | Panel on EURUSD | "Set your risk — 1% of balance." |
| 10–20s | Change SL from 20 to 30 pips | "Change the stop — the lot updates instantly." |
| 20–30s | Click the mode button | "Risk %, fixed amount, or fixed lot." |
| 30–40s | Click BUY | "One click: lot, stop loss and take profit set." |
| 40–50s | SL moves to breakeven | "Breakeven and trailing stop protect the trade." |
| 50–60s | CSV in Excel | "Every trade saved to your log." |

---

## B. Free product — Position Size Calculator Lite (MT5)

| Field | Value |
|---|---|
| Category | Indicators |
| File | `PositionSizeCalculatorLite.ex5` |
| Price | Free |

### Title
Position Size Calculator Lite MT5

### Short description
Free risk-based lot size calculator: enter your risk and stop loss, get the
exact lot size and money at risk for any symbol.

### Full description

A free, simple panel that answers one question: **what lot size should I
trade?**

- Risk as % of balance, a fixed amount, or a fixed lot
- Stop loss and take profit in pips — shown in points, price and money
- Lot size rounded down so the real risk never exceeds your setting
- Works on forex, JPY pairs, metals, indices, crypto and CFDs
- It is an indicator: it only calculates and never opens trades

**Want one-click trading?** The full *Position Size and Risk Manager*
adds BUY/SELL buttons with SL/TP, breakeven, trailing stop and a CSV trade
log: [link to the paid product — add after it is published].

---

## C. Buyer check-in message (private message, 3–5 days after purchase)

> Hi {name}, thank you for getting Position Size & Risk Manager.
> Is everything working on your account? If anything is unclear — the
> pip setting, the panel position, or an error message — just reply here
> and I will help.
> If the tool is useful to you, a short review on the product page helps
> other traders find it. Thanks!

Send it once. No offer or discount in exchange for a review.

---

## D. Beta tester post (MQL5 forum / groups that allow it)

> **Looking for MT5 traders to test a free position size panel**
>
> I built a risk-based position size calculator for MetaTrader 5 (lot
> size from % risk or a fixed amount, SL/TP in pips, money at risk). I am
> looking for a few traders to try it on a **demo account** before release
> and tell me honestly what works, what is confusing, and any bugs.
>
> Testers get the tool free. No review is required. Reply here or send me
> a private message if you are interested.

Only people who reply get access. No scraped emails, no unsolicited
messages.
