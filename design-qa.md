# Technocare mobile design QA

## Evidence

- Source visual truth: `https://technocare.az/` and `https://technocare.az/mehsullar`
- Source captures: `design-qa-artifacts/reference-home-mobile.png`, `design-qa-artifacts/reference-shop-mobile.png`
- Normalized source captures: `design-qa-artifacts/reference-home-normalized.png`, `design-qa-artifacts/reference-shop-normalized.png`
- Implementation captures: `design-qa-artifacts/implementation-home.png`, `design-qa-artifacts/implementation-shop.png`, `design-qa-artifacts/implementation-search.png`
- CSS viewport: 390 × 844
- Source capture pixels: 375 × 811; source browser density reported 1.0 after the viewport override. The in-app browser cropped its source capture to the visible content area, so the source was bicubic-normalized to 390 × 843 for like-for-like visual comparison.
- Implementation capture pixels: 390 × 843; density 1.0.
- State: unauthenticated Azerbaijani homepage and product catalog, light theme, live website imagery and WooCommerce catalog data.

## Full-view comparison evidence

The normalized source and implementation captures were opened together in one comparison input. The native homepage preserves the live hero subject, Technocare green/white/black palette, primary headline, supporting copy, source photography, rounded imagery, and section progression. The native Mağaza preserves the two-column product density, real product images, product hierarchy, green purchase controls, and persistent shopping navigation while intentionally replacing the website header, breadcrumbs, and inline quantity controls with native search, filters, result count, cart gating, and six-tab navigation.

The implementation is a native adaptation rather than an embedded web page. Differences in the carousel chrome, header controls, and card actions are expected outcomes of the approved mobile interaction model and do not remove source content.

## Focused-region comparison evidence

The above-the-fold homepage hero and intro section were checked at readable scale for logo treatment, crop, headings, paragraph line height, CTA visibility, section boundaries, and bottom navigation. The first two Mağaza rows were checked at readable scale for image sharpness, card spacing, truncation, price hierarchy, cart affordances, sticky search, filters, and touch-target separation. Separate additional crops were not needed because these regions are legible in the 390 × 843 captures.

## Required fidelity surfaces

- Fonts and typography: the implementation uses the existing app type system with weights and wrapping close to the website hierarchy. Display text remains readable at the target width, and product titles truncate without overlapping price or cart controls.
- Spacing and layout rhythm: the source's generous white sections, two-column catalog, rounded cards, and compact green controls are retained. Native sticky controls and the six-tab bar remain visible without viewport overflow.
- Colors and visual tokens: Technocare green, white, charcoal, pale green selection, and neutral gray surfaces match the source's semantic palette with adequate contrast.
- Image quality and asset fidelity: all visible logos, homepage photography, and product imagery are real website/WooCommerce assets. No source imagery is replaced with generated shapes, emoji, or handcrafted SVG substitutes.
- Copy and content: Azerbaijani source headings and descriptions are preserved through remote section blocks. Product names, SKU/brand metadata, prices, sale state, and availability are supplied by WooCommerce rather than duplicated in Flutter.

## Findings

No actionable P0, P1, or P2 visual findings remain.

- [P3] The native header logo is intentionally smaller than the website's centered mobile logo so notification and cart actions remain available.
- [P3] The homepage uses a static native hero frame for the current remote hero block instead of reproducing the website carousel controls. Website section content and imagery still update remotely.

## Interaction and runtime checks

- Tested six-tab bottom navigation entry into Mağaza.
- Tested 350 ms debounced search with `3108`, live suggestions, final one-result state, and result count.
- Tested superseded-request cancellation by starting a `31` search, continuing to `3108` after the first debounce interval, and confirming only the final result state rendered.
- Tested filter/sort bottom sheet visibility and controls.
- Verified real product images after loading and the guest-safe native catalog state.
- Checked browser console output after homepage, catalog, search, and filter interactions. No runtime errors were present; only Flutter bootstrap debug messages were recorded.

## Comparison history

- Pass 1: the preview initially showed image loading surfaces because cross-origin WooCommerce images were not available to the local browser renderer. This was preview infrastructure, not an app design mismatch; the local QA gateway was corrected to proxy the real source assets.
- Pass 2: the live hero and intro blocks were represented with their current website content and recaptured. The post-fix evidence is `design-qa-artifacts/implementation-home.png` and `design-qa-artifacts/implementation-shop.png`. The normalized comparison found no actionable P0/P1/P2 differences.

## Implementation checklist

- [x] Preserve website-sourced hero, editorial blocks, ordering, and visibility.
- [x] Preserve Technocare visual tokens and real assets.
- [x] Provide native sticky search, filters, product cards, cart affordances, and navigation.
- [x] Validate loading, search, filter, and catalog rendering at 390 × 844.
- [x] Check console output and interaction state.

## Follow-up polish

- Recheck text wrapping and hero crop on representative physical Android and iOS devices at larger accessibility text scales before store release.
- Re-run the same visual capture after the production WordPress plugin and HTTPS gateway are deployed so the release environment replaces the local QA gateway.

final result: passed
