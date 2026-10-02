# Product spec: Position Size & Risk Calculator (MT4/MT5)

Status: **DRAFT — research-grounded proposal, not an approved product.**
Nothing here authorizes listing, pricing, or building anything live. See the
root README's RESEARCH_ONLY / HUMAN_APPROVAL_REQUIRED policy.

Source data: [`research/mql5_competition_analysis_wide.json`](../research/mql5_competition_analysis_wide.json)
(10-niche competition scan) and
[`research/competitor_deep_dive_forex_trade_manager.json`](../research/competitor_deep_dive_forex_trade_manager.json)
(leading competitor deep dive), both scraped from the public MQL5 Market,
robots.txt-respecting, committed in `d9a136f`.

## 1. Why this niche

Out of 10 scanned niches, **Position Size Calculator** ranked #1 on a
competition-vs-proven-demand basis:

| Niche | Competition | Est. competitors | Price range (top 10) | % free | Paid w/ reviews | Max reviews on a paid product |
|---|---|---|---|---|---|---|
| **Position Size Calculator** | **Low** | **~140** | **$0–289** | 60% | 4 | **684** |
| Multi Timeframe Dashboard | Low | ~13 | $0–49 | 40% | 1 | 3 |
| Trade Journal | Low | ~140 | $0–45 | 80% | 0 | 0 |
| Copy Trading / Signal Copier | Medium | ~210 | $0–1,699 | 40% | 6 | 56 |
| Grid / Martingale EA | High* | ~7,910 | $99–1,299.99 | 0% | 10 | 221 |

(Full 10-row table in the JSON. The `*` on rows 5–10's "High" label is my
own annotation, carried over from the research session's own commentary
when it generated these numbers — MQL5's `filter` search is a loose match,
so a generic EA that merely mentions a keyword in its marketing copy can
inflate that niche's count. This caveat is **not** a field stored in the
JSON file itself — correcting an inaccurate claim in an earlier version of
this doc that implied it was.)

The combination that makes this niche stand out from the other two
"Low competition" niches: **unlike Trade Journal (0 paid products with any
reviews) and Multi Timeframe Dashboard (max 3 reviews on a paid product)**,
Position Size Calculator has a single paid product with genuine, large-scale
proof that traders pay for this: 684 reviews. That is demand without
saturation — not an untested category, and not a crowded one either.

## 2. The competitor to beat

**Forex Trade Manager MT5** — $99 one-time, by InvestSoft.
(Full detail: [`research/competitor_deep_dive_forex_trade_manager.json`](../research/competitor_deep_dive_forex_trade_manager.json))

- 4.98★ / 765 reviews total, ~57 purchases/month, published 2019, now on
  v3.70 (last updated 2026-06-18 per the page's own version label — still
  actively maintained).
- Free demo, 13,062 downloads.
- 5 feature groups: Key Features (risk/SL/TP-based position sizing, chart
  trade planning, external-order lot calc), Advanced Protection
  (multi-level breakeven, trailing stop variants), Stealth/Efficiency
  (hidden SL/TP, trailing pending orders), Precision Execution (limit
  pullback orders, one-click close/cancel, trade splitting), Customization
  (saved templates, OCO, risk:reward management).
- Single $99 buy-once tier. 10 activations per purchase. No subscription
  option.

**What it does well** (grounded in its 15 most recent reviews, all
4.5–5★ — this dataset had zero negative reviews to draw complaints from,
so these are strengths, not gap-by-absence):
1. Developer support responsiveness is the single most-repeated praise —
   reviewers name the developer personally and cite fast, outside-hours
   replies. This looks like their actual moat more than any one feature.
2. Mobile-to-desktop integration — reviewers specifically praise placing a
   trade from the MT5 mobile app and having the desktop panel
   auto-calculate the correct lot size for it.
3. Risk-based lot-size math people trust — the ATR/risk-based auto-lot
   calculation is repeatedly singled out as "brilliant"; it is also the
   product's core pitch.

## 3. Differentiation angles (structural, not review-sourced)

Honest caveat carried over from the deep dive: the 15 reviews fetched
contained **zero complaints** (consistent with a 4.98/5.0 average across
765 reviews — this is an unusually loved product). The three gaps below
come from what the product's own feature/pricing structure does *not*
offer, not from dissatisfied customers — there's no evidence yet that
these gaps bother Forex Trade Manager's existing buyers. Each should be
treated as a hypothesis to validate, not a proven wedge.

1. **No lower-priced tier.** Single $99 buy-only option, no $5–15/month
   rental. A cheaper entry tier could capture price-sensitive beginners
   this product doesn't try to serve.
2. **Hard activation cap (10).** Traders running several VPS/accounts may
   find this limiting. A more generous or unlimited-activation license is
   an easy claim to make and advertise.
3. **No trade journaling/analytics.** Nothing in its 5 feature groups
   covers win-rate stats or exportable trade history. Bundling a light
   trade log with position sizing combines two of this scan's "Low
   competition" niches (Position Size Calculator + Trade Journal) into one
   product — something neither leader currently does.

Not pursued: pulling specifically low-starred reviews to find real
complaints (would need an undocumented AJAX endpoint/rating filter not
present on the static page — skipped to stay robots.txt-compliant).

## 4. Proposed MVP scope (draft — needs your sign-off before anything is built)

**Core (parity with what traders already pay for):**
- Risk-based position size calculator (account %, fixed $, or pip-based
  risk → lot size)
- SL/TP display and management in currency/pips/points
- Basic breakeven and trailing stop

**Differentiators (not in the leading competitor):**
- Built-in trade log: every calculated/placed trade auto-logged with
  entry/SL/TP/lot size/outcome, exportable to CSV — a lightweight version
  of the "Trade Journal" niche bundled in, not a separate purchase
- Unlimited or clearly-more-generous activations than the 10-activation
  cap
- A cheaper entry tier alongside the full price, e.g. a "calculator only"
  tier vs. a "calculator + protection tools + journal" tier

**Explicitly out of scope for v1:** mobile app, copy-trading/signal
features, anything resembling the Grid/Martingale, Scalping, or Prop
Firm/FTMO niches this scan flagged as High competition.

## 5. Pricing — DECIDED (2026-10-02): launch FREE, price later on demand

**Decision:** v1 ships free. Rationale: use it to drive downloads/reviews/
traffic first; introduce pricing once there's enough signal (downloads,
review volume, feature requests) to justify it, rather than guessing a
number now.

**Honest caveat from this niche's own data, so the strategy accounts for
it rather than assumes free alone works:** in this scan's own top-10 for
Position Size Calculator, the *free* products have modest traction
(Blodsalgo Analitycs: 8 reviews; Position Size Calculator Gadget: 6
reviews) — the 684-review proof-of-demand in this niche sits on the one
*paid* product, not on a free one. So "free" is a reasonable way to
reduce friction and start collecting usage/reviews, but it is not itself
what the research showed people value — the risk-based lot-size
calculation is. Being free doesn't guarantee the traction Forex Trade
Manager got; it only removes the price objection as a reason not to try.

**Practical plan so "we'll price it later" is actually executable, not
just deferred indefinitely:**
- Build it so a later paid tier is a straightforward add, not a rebuild:
  keep the differentiators from section 4 (trade log, generous
  activations) as the natural "Pro" tier to introduce later, while the
  core risk/lot-size calculator stays free indefinitely (this matches
  how several of the free products in this niche already behave — free
  core tool, monetization elsewhere).
- Define, before launch, what "enough demand" looks like so the pricing
  decision isn't made on a vibe either (e.g. a download/review/active-user
  threshold, or a specific number of users explicitly asking for the
  journal/Pro feature). That threshold isn't set yet — still open.

## 6. Next steps (none of these are authorized yet)

- [ ] Decide MVP feature list for real (trim/expand section 4)
- [x] Decide pricing direction (section 5) — **free v1, price later on demand** (2026-10-02)
- [ ] Define the demand threshold that triggers introducing a paid tier
- [ ] Source or scope the actual indicator/EA build (not covered by this
      repo's research scripts — this is a dev task)
- [ ] Only once a human has approved a specific storefront listing: draft
      it under `storefront/`, per the root governance policy
