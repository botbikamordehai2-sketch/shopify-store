# automation

Scripts and agents that assist with store operations (content, pricing checks,
market research, etc.).

**RESEARCH_ONLY / HUMAN_APPROVAL_REQUIRED**: any script in this folder that
could write to the live Shopify store (products, pricing, orders, theme,
customers) must only ever run in a dry-run / draft / proposal mode by
default. No script here may call the live Shopify Admin API with write
intent without an explicit, logged human approval step immediately before
the call. See the root README for the full policy.
