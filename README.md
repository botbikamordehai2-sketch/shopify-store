# Shopify Store

Repo for a Shopify store project: market/product research, storefront build,
and light automation around store operations.

## Structure

- `docs/` — architecture notes, decisions, setup guides.
- `research/` — market and demand research. Currently holds
  [`coursera_syllabi.json`](research/coursera_syllabi.json), a syllabus
  summary (course, institution, level, duration, rating, modules) for six
  Coursera specializations relevant to running this store (Shopify, digital
  marketing, SEO, Google Analytics, AI for marketing, AI agents &
  automation) — the learning track backing this project. Future market/demand
  research goes here too.
- `products/` — product sourcing notes, catalog drafts, pricing analysis.
- `storefront/` — theme/code and configuration for the storefront.
- `automation/` — scripts/agents assisting store operations.

## Governance: RESEARCH_ONLY / HUMAN_APPROVAL_REQUIRED

This repo follows the same research-only discipline used elsewhere in this
AI workspace (see the memory-for-all governance model):

- Everything produced here — research, product lists, pricing analysis,
  storefront drafts, automation scripts — is **advisory**, not a standing
  instruction to change the live store.
- **No automated write to the real Shopify store** (products, pricing,
  inventory, orders, theme, customers, discounts) is permitted without an
  explicit, human-in-the-loop approval step immediately before that write.
- Any script in `automation/` (or elsewhere) that touches the Shopify Admin
  API must default to dry-run / draft / proposal mode, and must clearly log
  what it *would* do before anything is ever applied live.
- A human reviewing and explicitly approving a specific change is required
  every time — a prior approval does not carry forward to future runs or
  broader scope.

When in doubt, default to producing a reviewable artifact (file, draft,
report) rather than taking a live action.
