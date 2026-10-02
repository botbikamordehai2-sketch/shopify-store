# Shared team memory — Shopify store

Updated: 2026-10-02 (Asia/Jerusalem)
Status: RESEARCH_ONLY / PROPOSAL / HUMAN_APPROVAL_REQUIRED

## Authority and coordination
Moti is the human decision owner. Gemini Notebook coordinates planning; ChatGPT prepares storefront drafts. Other agents must read this file and the root README before work.
This file is a shared reference, not automatic model memory or a live communication channel. Notebook sources may require refresh. Notion remains the task/approval system; this document does not grant approval.

## Project
Repository structure verified: docs/, research/, products/, storefront/, automation/.
Requested design brief: Home Organization Essentials for Israel; mobile-first, Hebrew, RTL, ILS.
The current repository also contains trading-tool research and MQL5 code. Do not treat these as home-organization products or delete them.
Shopify connection previously reported trial, ILS, Israel and EDT. Dawn was reported by Gemini/user; its actual version and source have not been inspected. Israel in basic shop information does not verify Markets configuration.

## Storefront draft
Path: storefront/drafts/home-organization/
Files: README.md, proposal.json, sections/home-organization-hero.liquid, locales/he.json, locales/en.default.json.
Scope: additive hero section with scoped RTL and translation fragments, not a full Dawn theme.
Liquid and locale validation passed using bundled fallback schemas. No browser, complete Dawn integration or live store tests performed.
Merge translation fragments into existing locales; never replace full Dawn locale files.
Use dynamic presentment money formatting; do not hardcode currency conversion.
Asia/Jerusalem timezone is a proposal only.

## Execution boundary
Moti authorized public GitHub documentation and draft publication on 2026-10-02.
That authorization does not permit Shopify API calls, app opening, product changes, pricing, settings, theme sync, upload, publish, payments or paid services.
Every specific live change requires explicit human approval.
No credentials, tokens, customer data or private chat transcripts belong in this public repository.

## Next steps
Review draft with Notebook. Obtain the actual Dawn export/version through a separately authorized action. Verify mobile, Hebrew/English, full RTL, keyboard focus, zoom and currency on an unpublished copy after explicit approval.
The user created a local folder and saved the explanation as TXT; actual local code-file presence has not been verified. The README is documentation, not a terminal command.

## Update protocol
Record date, author, changed files, evidence/commit and limitations. Distinguish verified results from reported claims. Never mark human approval on Moti's behalf.
