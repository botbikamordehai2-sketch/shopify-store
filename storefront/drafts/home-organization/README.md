# Home organization — Dawn proposal

Draft only. No Shopify API, upload, sync, deployment or remote Git write performed.

Repository inspected at dfa7fa14682f73724aa2f19bc1f864683ea9e577. Its storefront contains no Dawn source. Its current products/research primarily concern trading tools; home organization is the supplied design brief, not a verified repository niche. Dawn and its version have not been inspected on the store.

This package is an additive hero section, not a complete theme or a replacement for Dawn. It contains mobile-first logical CSS, Hebrew/English translation fragments, a configurable collection link, semantic markup and keyboard focus styling. No supplier, shipping, discount or performance claims are included.

After human approval, integrate with an exported copy of the actual Dawn theme. Merge the organization keys into existing locale files; never replace full Dawn locales with these fragments. Add the section through the theme editor to an unpublished theme copy. Hebrew must be available in the theme language configuration. The draft section applies RTL for Hebrew locally; full header, navigation, cart and product RTL requires inspection of the actual theme. Do not replace the existing home template.

Use Dawn's existing price rendering and money_with_currency for any later custom price component. Display presentment currency dynamically; these files do not force currency or change Markets settings. The requested ILS setting is a project target, not a hardcoded price conversion.

proposal.json is documentation only, not Shopify settings_data.json. Its timezone is a proposal requiring approval, not an applied setting.

Before accepting: verify at 320/375/768/1440 px, 200% zoom, keyboard focus, Hebrew/English switching, configured and empty collection, real product currency, and complete Dawn header/cart/product RTL. Liquid validation does not replace browser testing. No live or browser test has been performed.
