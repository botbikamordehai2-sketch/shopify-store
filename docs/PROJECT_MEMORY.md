# Project memory — shared by all agents

**Read this file first, before any work in this repo.** It is the single
shared memory for every model (Claude, ChatGPT, Gemini, n8n workflows) and
for Moti. Models do not share memory with each other — only what is written
here and committed to GitHub is shared.

This repo is **public**. Never write credentials, tokens, account numbers,
customer data, private chat transcripts or personal contact details here.

## 1. Where things live

| What | Where | Who updates it |
|---|---|---|
| Current state + decisions log | this file, §4 and §5 | Claude |
| Product spec + task checklist | `products/position_size_calculator_spec.md` (§6) | Claude |
| EA / Lite source + test results | `products/position_size_risk_manager/` | Claude |
| Market research data | `research/` | Claude (scripts in `automation/`) |
| Repo-wide safety policy | root `README.md` (RESEARCH_ONLY / HUMAN_APPROVAL_REQUIRED) | Moti approves changes |

Anything not committed to GitHub does not count as shared memory.

## 2. Roles and permissions

| Who | Can do | Cannot do |
|---|---|---|
| **Moti** (owner, human) | Every decision. Only he approves anything live: prices, MQL5 Market upload/publish, Shopify changes, payments, messages to real people, account settings. | — |
| **Claude** (Claude Code on Moti's PC) | Read/write this repo, commit and push to `main`, compile in MetaEditor, run Strategy Tester and demo-account tests, keep this file and the spec current. Main builder. | Live store/Market actions, real-money accounts, messaging people, marking approval on Moti's behalf. |
| **ChatGPT** | Read the repo, propose changes, draft text — handed to Moti or Claude. Used only when Moti asks, to speed work up. | Push to `main`. If it must commit, use a branch `agent/chatgpt-<topic>` for review. |
| **Gemini** | Same as ChatGPT. | Same as ChatGPT (`agent/gemini-<topic>`). |
| **n8n workflows** (e.g. CONCERT2) | Separate project; mock/research-only. | Not connected to this repo; no writes here. |

## 3. Update protocol (when and how)

Update this file **in the same commit** whenever:
- Moti makes a decision → add it to §5 with the date.
- A task is finished or blocked → update §4 and the spec checklist.
- A test is run → record the result and the commit it tested.

Each §5 entry: date · who · what changed · evidence (commit hash or file) ·
**verified** (we ran/checked it) or **reported** (someone said so).
Never record an approval Moti did not give in this conversation or in writing.

## 4. Current state (2026-10-02)

- **Product:** Position Size & Risk Manager — MT5 Expert Advisor, sold on the
  MQL5 Market (not Shopify). Price **$68**, 20 activations.
- **Paid EA:** built; compiles 0/0; Strategy Tester passed on EURUSD, USDJPY,
  XAUUSD, US30; live demo check passed (lot/risk, mode button, BUY with SL/TP).
- **Free Lite indicator:** built; compiles 0/0; not yet checked on a chart.
- **Next:** check Lite on a chart → decide launch price → draft MQL5 product
  page + buyer check-in message → beta tester program → Moti uploads →
  price-change mechanics (last) → reviews (after launch).
- **Shopify:** on hold; Claude's Shopify connector fails auth.
- **Reminder:** scheduled task `psrm-update-reminder` (1st and 15th, 10:00)
  on Moti's PC.

## 5. Decisions log

| Date | Who | Decision | Evidence |
|---|---|---|---|
| 2026-10-02 | Moti | MVP scope: calculator, SL/TP, breakeven, trailing, CSV log; tiers + analytics to v2 | spec §4, `5558bb1` |
| 2026-10-02 | Moti | Claude builds everything; GPT only on request | spec §6, `7c5cd48` |
| 2026-10-02 | Moti | Price $68 flat ($10→$29 plan dropped: MQL5 minimum is $30 — verified on mql5.com/en/market/rules) | spec §5, `186cb6c` |
| 2026-10-02 | Moti | Launch plan: free Lite, pro product page, regular updates, launch price | spec §5c, `5fbdb53` |
| 2026-10-02 | Moti | No paid/incentivised reviews or scraped emails; opt-in beta testers instead | spec §6, `5d62246` |
