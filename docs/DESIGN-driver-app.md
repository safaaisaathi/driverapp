# DESIGN-driver-app.md: Safai Sathi Driver App Visual Spec

```
AUDIENCE    : AI coding agent (machine-parsed). Human readability is secondary.
PARSE MODE  : literal. MUST/NEVER/ALWAYS = hard rule. No rule is optional unless marked [optional].
STACK       : Flutter (stable) + Material 3 (heavily themed) + Riverpod + flutter_map + flutter_svg + Noto Sans / Noto Sans Gujarati (bundled)
SCOPE       : Driver app only. User app is covered by DESIGN.md. Admin web panel is OUT OF SCOPE.
THEMES      : light [from-wireframe:p1..p26] + dark [inferred]
SOURCE      : docs/"Safai Sathi Driver App Wireframe.pdf", 26 pages, converted to PNG at /tmp/opencode/wireframe_png/page-01.png .. page-26.png. Text extraction at /tmp/opencode/wireframe.txt.
CONTRACT    : DESIGN.md Sections 2+5 token names are KEPT. This file is the driver-app page-template and component layer on top of DESIGN.md. Where the wireframe shows something DESIGN.md does not cover, this file defines it as a driver override. PRD-2 §0.16 governs behaviour.
```

## TAG LEGEND

| Tag | Meaning |
|---|---|
| `[from-wireframe:pN]` | Directly visible on PDF page N (PNG page-0N.png) |
| `[est]` | Visible but value estimated; snapped to the 4 dp grid |
| `[inferred]` | NOT in the wireframe; derived from DESIGN.md tokens and personality |
| `[new]` | Screen that exists only in the driver-identity rebuild (spec issue #1) |
| `[modified]` | Wireframe screen kept, content/layout changed for the rebuild |
| `[removed-T8]` | Binny mascot usage removed by the identity spec (T8 = trust/identity track) |

## AUTHORITY ORDER (on conflict, higher wins)

1. DESIGN.md Section 5 (Consistency Law)
2. DESIGN.md Section 2 (Tokens)
3. This file (DESIGN-driver-app.md), Sections 2+5
4. This file, Sections 3-9
5. Agent judgment (only when 1-4 are silent; then match Section 0 attributes and add the new rule to this file)

All product behaviour (screens, data, flows) comes from PRD-2 (driver app). This file decides only how things look and where they go.

---

## 0. META

| Field | Value |
|---|---|
| Name | Safai Sathi Driver App (working name) |
| Product type | Flutter mobile app for drivers: GPS shift tracking, ward completion, code-based shift start |
| Accent policy | Brand = green family. ONE accent hue (orange) for selection and attention only: selected chip, location pin, "needs attention" highlights. Ink (near-black) is the primary action color |
| Signature | **Contour card**: a large rounded card filled with topographic contour lines (Section 4.9). Used for the single most important status on a screen |
| Mascot | **Binny removed** from driver empty/success screens [removed-T8]. No mascot appears on any driver screen. Replacement: neutral icon in a colored circle (Section 4.16) |

| Attribute | Value | Numeric backing |
|---|---|---|
| corner-radius | very large | cards 28 dp, sheets 32 dp, inputs 20 dp, buttons/chips/nav full (999) |
| density | roomy | control height 56 dp minimum, driver button height 64 dp, card padding 20 dp, page padding 20 dp |
| contrast | strict AA | body text >= 4.5:1, UI shapes >= 3:1 (DESIGN.md Appendix D) |
| motion | calm | 120-320 ms, ease-out, no bounce, no parallax |
| depth | soft | cards flat on tinted page; floating layers (nav pill, glass bar, sheets) use soft shadow |
| iconography | thin outline | Material Symbols Outlined (rounded), 24 dp, weight 300, grade 0 |
| whitespace | generous | card gap 12 dp, section gap 24 dp |
| alignment | left aligned text; primary action centered at the bottom | CTA is a full-width black pill |
| language | bilingual | Gujarati + English, toggle always reachable; strings never hardcoded |

### Decision log (agent MUST honor)

| ID | Decision | Reason |
|---|---|---|
| D-101 | The driver app reuses DESIGN.md Section 2 token names and Section 5 rules verbatim; driver-specific overrides live in this file's Section 2 | Keeps token contract valid across both apps |
| D-102 | `color.primary` = ink (near-black) for the primary action pill, per DESIGN.md D-02. Brand green is `color.brand` | Matches wireframe black CTAs |
| D-103 | Permission screens 1-3 share identical layout (icon circle, title, body, two buttons) differing only in icon, copy, and button labels [from-wireframe:p1,p15,p16] | Single PermissionRationale component |
| D-104 | Start Shift code field uses a single `XX-0000` code field (7 visible slots incl. hyphen) replacing the 4-box PIN pattern [new] | Spec issue #1: van + PIN replaced by driver identity code |
| D-105 | Binny mascot is removed from all driver screens [removed-T8]. Empty states use a neutral icon instead | Identity spec T8 removes mascot from driver app |
| D-106 | Dark theme inverts: primary pill is near-white with dark label; surfaces step dark | DESIGN.md Section 2.7 rules applied to driver |
| D-107 | Driver sizes (56/64/72/80 dp) are used everywhere on driver screens; never mixed with user sizes | CL-34 |
| D-108 | Map tiles are OSM raster tiles, tinted with ColorFilter per theme [inferred] | DESIGN.md D-12 |

---

## 1. DESIGN DNA (extracted from the wireframe)

| Attribute | Value | Confidence |
|---|---|---|
| Layout archetypes | Map shell (M1): full-bleed map, glass top bar, draggable sheet, pill nav bottom. Card-list shell (M2): page background, large `display` title, stacked rounded cards, pill nav bottom. Flow shell (M3): full-screen task, back/close top-left, one black pill CTA pinned bottom, no nav [from-wireframe:p4,p8,p2] | high |
| Page background (light) | off-white / very light grey `#F5F5F5` [est] | med |
| Card surface | white `#FFFFFF`, no border, soft shadow | high |
| Brand green | dark `#1B7A3F`, mid `#6DB36F`, leaf `#B5CF8A` | med `[est]` |
| Accent | orange `#F0873A` for the selected chip and the location pin | med `[est]` |
| Ink | `#111A14` | med `[est]` |
| Font | Noto Sans + Noto Sans Gujarati fallback | high |
| Heading scale | hero number 56, display 36 light, body 16 | med `[est]` |
| Radius | cards ~28, sheet top ~32, inputs ~20, buttons/chips/nav pill | high |
| Buttons | black full-width pill, white 16 dp semibold label, trailing `→` icon [from-wireframe:p2,p4,p12,p13] | high |
| Chips | small pills; selected = orange fill, ink text | high |
| Navigation | white floating pill; driver pill height 80, item circle 64; active item = black circle with white icon | high |
| Top bar | translucent glass pill, height 64, inset 16, `glass` fill, `elev2`; contents: route icon, two-line title (route name `titleSmall`, TrackingBadge `bodySmall` muted), settings icon button right [from-wireframe:p4,p5,p7,p9,p14,p23,p24,p25,p26] | high |
| Small stat tiles | rounded tile, label top-left, round arrow button top-right, big number, faint dot texture | high |
| Signature pattern | contour-line card, lines in a tint of the card color | high |
| Icons | thin outline, Material Symbols Outlined, 24 dp, weight 300 | med |
| Not in wireframe | dark theme values, Gujarati glyph metrics, code field XX-0000, confirm card, welcome-back card | n/a, `[inferred]` / `[new]` |

---

## 2. DESIGN TOKENS

### 2.1 Color tokens: `lib/core/theme/app_colors.dart` (reuse DESIGN.md Section 2.1 verbatim)

The driver app imports the same `AppColors` extension from DESIGN.md. Driver-specific color usage:

| Role | Token | Wireframe evidence |
|---|---|---|
| Primary action fill | `colors.primary` + `colors.onPrimary` | black pill CTAs on every screen [from-wireframe:p2,p4,p12,p13,p17,p18,p19,p20,p25] |
| Brand surface / emphasis | `colors.brand`, `colors.brandSoft`, `colors.brandMid`, `colors.brandLeaf` | green route chip [p2], green ContourCard [p4,p12,p25], permission icon circles [p1,p15,p16] |
| Selection / attention | `colors.accent` (fill, ink text), `colors.accentStrong` (text), `colors.accentSoft` | orange "Received" pill [p10], orange location pin [p20 report map], orange left bar on unread notices [p8] |
| Page and cards | `colors.background`, `colors.surface`, `colors.surfaceMuted` | page bg [all], white cards [all], light-green modal/info cards [p12 info banner, p19 chip] |
| Lines | `colors.border` (decorative), `colors.borderStrong` (input outline, 3:1) | PIN box borders [p2], red error borders [p3] |
| Text | `colors.textPrimary`, `colors.textMuted` | all body text |
| Errors | `colors.error` | "Wrong PIN. Try again." [p3] |

Driver-only observed colors (mapped to tokens; if no match, logged in decision log):

| Observed color | Token mapping | Wireframe page |
|---|---|---|
| Black pill `#1A1A1A` | `colors.primary` | p2, p4, p12, p13, p17, p18, p19, p20, p25 |
| Light green pill `#E8F5E9` | `colors.brandSoft` | p2 route chip, p19 "Applies to East route" chip |
| Green done badge | `colors.statusResolved.fill` / `colors.brand` | p4 WardRow done |
| Orange unread bar | `colors.accent` | p8 notices cards |
| Orange "Received" pill | `colors.accentSoft` fill + `colors.accentStrong` text | p10 |
| Red error outline + text | `colors.error` | p3 |

### 2.2 Type: `lib/core/theme/app_text.dart` (reuse DESIGN.md Section 2.2 verbatim)

Fonts: `NotoSans` (400, 500, 600, 300) and `NotoSansGujarati` (400, 500, 600), bundled in `assets/fonts/`. Gujarati strings use line height >= 1.5 x size. Never use a size below 14 sp except `attribution` (12 sp, map attribution and legal lines only). Never use weight 700 or above.

| Style | Size / line | Weight | Driver use |
|---|---|---|---|
| `heroNumber` | 56 / 60 | 400 | route progress big number "4" [p4,p5,p7,p14,p23,p24,p25,p26] |
| `display` | 36 / 44 | 300 | screen titles ("Start shift", "Notices", "Settings") [p2,p8,p21] |
| `headline` | 28 / 36 | 500 | permission titles, modal titles ("Mark Ward 5 done?") [p1,p15,p16,p6] |
| `title` | 20 / 30 | 600 | card titles ("Ward 5", "Missed collection · Ward 5") [p4,p10] |
| `titleSmall` | 16 / 24 | 600 | list item titles, stat labels, glass bar subtitle |
| `body` | 16 / 24 | 400 | default text, permission bodies |
| `bodySmall` | 14 / 22 | 400 | secondary text ("Done · 09:42", timestamps) |
| `label` | 14 / 20 | 600 | chips, field labels ("Van", "Route", "PIN", "Language", "Theme") |
| `button` | 16 / 24 | 600 | all buttons ("Start Shift", "Allow", "Not now") |
| `attribution` | 12 / 16 | 400 | map attribution only |

### 2.3 Space, radius, elevation, sizes: `lib/core/theme/app_tokens.dart` (driver overrides)

```dart
class AppSpace {
  static const double unit = 8;
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 20, xxl = 24, xxxl = 32, huge = 40;
  static const double page = 20;
  static const double cardGap = 12, cardPad = 20, sectionGap = 24;
}
class AppRadius {
  static const double md = 12;
  static const double control = 20;
  static const double card = 28;
  static const double sheet = 32;
  static const double pill = 999;
}
class AppSize {
  static const double touchMin = 48, touchDriver = 56;
  static const double buttonUser = 56, buttonDriver = 64;
  static const double bigAction = 72;
  static const double iconButton = 48, iconButtonDriver = 56;
  static const double navHeight = 72, navItem = 56, navHeightDriver = 80, navItemDriver = 64;
  static const double glassBarHeight = 64, glassBarInset = 16;
  static const double icon = 24, iconSmall = 20;
  static const double vanMarker = 44, pinWidth = 40, pinHeight = 52, markerHit = 48;
  static const double thumb = 72;
  // Driver-only additions
  static const double permissionIconCircle = 96;   // [est]
  static const double codeBox = 56;                 // [est] single XX-0000 field height 64
  static const double confirmCardPad = 20;          // [est]
  static const double wardRowHeight = 72;           // [from-wireframe:p4]
  static const double pillNavDriver = 80;           // [from-wireframe:p4..p26]
}
```

Elevation (reuse DESIGN.md):

| Token | Value | Use |
|---|---|---|
| `elev0` | none | cards on the page (light) |
| `elev1` | blur 16, y 4, black 6% | cards on map / green background |
| `elev2` | blur 24, y 8, black 12% | nav pill, glass bar |
| `elev3` | blur 32, y 12, black 16% | bottom sheets, dialogs, modals |
| `glass` | fill `surface` at 82% opacity + `BackdropFilter` blur sigma 16 | glass top bar only |

Z-order: map, map markers, sheet, glass bar, nav pill, snackbar, dialog.

### 2.4 Theme builder (reuse DESIGN.md Section 2.4 verbatim)

Driver screens read colors only via `context.colors`, never `Theme.of(context).colorScheme` directly for brand or status colors.

### 2.5 Breakpoints (reuse DESIGN.md Section 2.5 verbatim)

| Class | Width | Behaviour |
|---|---|---|
| `compact` | < 360 | page padding 16, hero number 48, nav labels hidden |
| `regular` | 360-599 | default |
| `large` | >= 600 | content max width 520 centered; driver landscape: map 60% + panel 40% |

### 2.6 Motion tokens (reuse DESIGN.md Section 2.6 verbatim)

| Token | Value |
|---|---|
| `dur.fast` | 120 ms |
| `dur.base` | 200 ms |
| `dur.slow` | 320 ms |
| `dur.ambient` | 2400 ms |
| `curve.standard` | `Curves.easeOutCubic` |
| `curve.exit` | `Curves.easeInCubic` |

### 2.7 Dark-mode rules (reuse DESIGN.md Section 2.7 verbatim)

Both themes define identical fields. Surfaces step dark. Brand flips to `#6DB36F` family. Primary flips to near-white pill. Map tinted dark. ContourCard identical in both themes.

---

## 3. LAYOUT SYSTEM

### 3.1 Grid and safe areas

- Page horizontal padding `AppSpace.page` (20 dp; 16 on `compact`). Content respects `SafeArea`. Floating bars sit `AppSpace.lg` (16 dp) inside the safe area.
- Vertical rhythm: card gap 12, section gap 24, card padding 20. Everything snaps to the 4 dp grid.
- Single column only on portrait. Two-up tiles use 2 equal columns with 12 dp gap.

### 3.2 Shells (choose exactly one per screen)

| ID | Name | Structure | Used by |
|---|---|---|---|
| M1 | Map shell | full-bleed map; glass top bar (top); draggable sheet; pill nav (bottom) | D2 Live Route |
| M2 | Card-list shell | page background; large `display` title; stacked cards; pill nav (bottom) | D3 Notices, D4 Pending Reports, Settings, Trip history |
| M3 | Flow shell | full-screen task; round close/back button top-left; one black pill CTA pinned bottom; no nav | Splash, Welcome [new], Permission 1-3, Start Shift code entry [new/modified], Confirm card [new], D5 End Shift |
| M4 | Detail sheet shell | tinted header area with art or map; white rounded sheet (radius 32) holding content; back button top-left | Report detail modal [p20] |
| M5 | Splash/onboarding shell | background with organic leaf blob, title, black pill CTA | Splash |

### 3.3 Dimensions

| Element | Spec |
|---|---|
| Glass top bar | height 64, inset 16 from safe top and 16 from sides, radius pill, `glass` fill, `elev2`. Contents: route icon slot (48 circle, `brandSoft` fill) + two-line text (route name `titleSmall`, TrackingBadge `bodySmall` muted) + ONE settings icon button on the right (48 circle) [from-wireframe:p4,p5,p7,p9,p14,p23,p24,p25,p26] |
| Pill nav (driver) | height 80, auto width (3 items: Route, Notices, Reports), centered, bottom inset 16 + safe area, radius pill, `surface`, `elev2`, inner padding 8. Item circle 64. Active item = `primary` circle with `onPrimary` icon. Inactive = transparent with `textMuted` icon. No labels (icons + `Semantics` label) |
| Bottom sheet on map | radius 32 top, `surface`, `elev3`, grab handle 40 x 4 `borderStrong`. Snap points: collapsed 0.22, default 0.36, expanded 0.88. Sheet bottom padding includes nav height + 16 |
| Page title block (M2) | top padding 24 below safe area; `display` title; optional `bodySmall` muted subtitle 8 below |
| CTA bar (M3) | pinned at bottom: padding 20 horizontal, 16 bottom + safe area; button height 64 (driver); 16 dp gradient fade of `background` above it when content scrolls under |
| Contour card | min height 160, radius 28, padding 20; content left, optional round 48 arrow button top-right |
| Stat tile | 2-up, min height 112, radius 28, padding 16 |
| Permission screen stack | M3 shell; icon circle 96 dp `brandSoft` fill at top; title `headline`; body `body`; large empty middle; black pill "Allow →" / "Open settings →" pinned bottom; green text secondary button below [from-wireframe:p1,p15,p16] |
| Code field (Start Shift) | single `XX-0000` field: height 64, radius 20, fill `surface`, 1.5 `borderStrong` outline, label above (8 dp gap, `label`), monospace-ish numeric input [new, D-104] |
| Confirm card | white card radius 28, padding 20, full width below code field; shows name, van, ward count, masked phone [new] |
| WardRow | height 72, `surface` card radius 28; leading 48 circle (`primary` + number if next, `brand` + check if done, `surfaceMuted` + number if pending); title `titleSmall`; done time `bodySmall` muted [from-wireframe:p4] |

### 3.4 Spacing relations (relation -> token)

| Relation | Token |
|---|---|
| Page edge to card | `AppSpace.page` (20) |
| Card to card (same group) | `cardGap` (12) |
| Section to section | `sectionGap` (24) |
| Card inner padding | `cardPad` (20), tiles 16 |
| Icon to its label | 8 |
| Label to field | 8 |
| Field to field | 16 |
| Chip to chip | 8 |
| Title to subtitle | 8 |
| CTA to content above | >= 16 |
| Floating bar to screen edge | 16 + safe area |

### 3.5 Alignment and hierarchy

- Text left aligned. Big numbers left aligned inside their card.
- One primary action per screen, centered full width at the bottom (M3) or as a prominent pill button in the sheet (M1).
- Hierarchy order: (1) the one signature/status element (ContourCard), (2) the primary action, (3) supporting cards, (4) utilities.
- Header actions are round icon buttons (48 driver 56), never text links.

---

## 4. COMPONENT LIBRARY (Flutter widget specs)

### 4.0 Global state model

| State | Visual rule |
|---|---|
| default | as specified |
| pressed | scale 0.98 for 120 ms + overlay `textPrimary` at 8% |
| focused (keyboard/TalkBack) | 3 dp outline `brand` offset 2, never removed |
| disabled | 40% opacity, no shadow, `Semantics(enabled: false)` |
| loading | label replaced by 20 dp circular progress; control not tappable |
| error | `error` outline 1.5 + helper text with icon, never color alone |
| selected | per component (chip = accent fill; nav = ink circle) |

### 4.1 AppButton

| Variant | Fill | Label | Size | Use |
|---|---|---|---|---|
| `primary` | `colors.primary` | `onPrimary`, `button` | full width, height 64 (driver), pill | the ONE main action per screen |
| `secondary` | transparent, 1.5 `borderStrong` outline | `textPrimary` | same | alternative action |
| `tonal` | `colors.brandSoft` | `colors.brand` text | same | safe, low-emphasis action ("Later", "Open settings") |
| `text` | none | `colors.brand` | height 48 | inline link-like action |

Trailing icon 24 dp allowed on `primary` ("Start Shift →", "Back to start →"). No leading icons on primary.

### 4.2 AppIconButton

48 dp circle (driver 56). Fill `surface` (or glass when on the map), icon 24 outline `textPrimary`, `elev2` only when floating on a map. Header buttons use `surfaceMuted` fill, no shadow. Always has `Semantics(label:)` and tooltip.

### 4.3 AppChip

Height 48, radius pill, padding 16 horizontal, icon 20 + label (`label`). Unselected: `surface` fill + 1.5 `borderStrong`. Selected: `accent` fill, `onAccent` text, leading check icon 20. Chips wrap with 8 dp gaps; row never scrolls when <= 5 chips.

### 4.4 AppTextField

Pill-like: radius 20, height 56 (multi-line min 96), fill `surface`, 1.5 `borderStrong` outline, label above (8 dp gap, `label`), hint `textMuted`. Focus: outline `brand` 2.5. Error: outline `error` + helper text with `error` icon.

### 4.5 CodeField (driver override, [new])

Single `XX-0000` field replacing the 4-box PIN pad. Height 64, radius 20, fill `surface`, 1.5 `borderStrong` outline, label above. Numeric keypad, auto-formats hyphen after 2 chars. On validation error: outline `error` 1.5 + InlineError below [from-wireframe:p2,p3 pattern, adapted].

**Amended 2026-10-30 (driver demo feedback): OTP boxes.** The flat field becomes one box per character: 2 letter cells + the dash as PLAIN TEXT (never a box) + 4 digit cells. Cell size `AppSize.codeBox` (56), cell radius `AppRadius.control` (20), 1.5 `borderStrong` outline, 2.5 `brand` on the active cell, `error` on a bad shape, fill `surface`, per-box text `text.headline`. The row is `FittedBox(scaleDown)` so six 56 dp cells never overflow a 360 dp screen. The editable seam stays a hidden `TextField` (the formatter/keyboard-flip contract is unchanged) painted behind the boxes; the visible row tap focuses it, and an extra short line (`8 dp`) separates the cells.

**Amended 2026-10-31 (identity review): edit cycle + returning surface.** After a search the boxes drop focus and the result action owns the pinned CTA; tapping the boxes re-enters editing and the search CTA returns. A returning device never renders the boxes: the welcome-back card is the only surface, every failure shows inside that card (title + body, the shared error tint) with the pinned CTA = Retry, and `Different driver?` is the only way to the entry form. The entry form reached that way carries a top-left back button (56 dp driver icon size, page margin) and system back returns to the welcome card; a device that never came through the link has no arrow.

### 4.6 PillNav (driver)

See 3.3. Items: Route, Notices, Reports. Badge: 20 dp circle `accentStrong` fill + white 14 sp number, top-right of item, for unread counts only.

### 4.7 GlassBar (driver override)

See 3.3. Route icon slot + two-line title + TrackingBadge + settings icon button. If `BackdropFilter` unavailable, use `surface` at 100%.

### 4.8 TrackingBadge

Pill in the glass bar: 8 dp `brand` dot + "Tracking active" text. Label ellipsizes (`Flexible`) and never overflows [from-wireframe:p4..p26].

### 4.9 StatusChip

Height 32, radius pill, padding 12 horizontal, `soft` fill, `text` color label, leading 20 dp icon in `text` color.

| Status | Label key | Icon |
|---|---|---|
| `received` | `status.received` | `inbox` |
| `assigned` | `status.assigned` | `assignment_ind` |
| `resolved` | `status.resolved` | `check_circle` |
| `escalated` | `status.escalated` | `priority_high` |
| `queued` | `status.queued` | `cloud_off`, `surfaceMuted` fill + `textMuted` text |

Always icon + label + color. A dot alone is never a status.

### 4.10 Cards

| Card | Spec |
|---|---|
| Basic card | `surface`, radius 28, padding 20, `elev0` (page) or `elev1` (on map/green) |
| Stat tile | `surface`, radius 28, padding 16; label `titleSmall` top-left; 48 round arrow button top-right (`surfaceMuted`); value `headline` bottom-left |
| Complaint card | radius 28, padding 16; ticket ID `bodySmall` muted, category title `titleSmall`, time `bodySmall` muted, status chip |
| Info card | `brandSoft` fill, no shadow, leading icon 24 `brand`, `body` text |
| Notice card | `surface`, radius 28, unread = 4 dp left bar `accent` + bold title [from-wireframe:p8] |
| Confirm card [new] | `surface`, radius 28, padding 20, full width; 4 info rows (name, van, ward count, masked phone) each with leading icon 20 and value `body` |

### 4.11 ContourCard (SIGNATURE, rule CL-12)

Widget `ContourCard({child, seed, onArrow})`. Fill `brandMid`, radius 28, `ClipRRect`, min height 160, padding 20, all text ink. `CustomPaint` draws contour lines (same as DESIGN.md 4.9). Seed = stable per entity (hash of `wardId` or `shiftId`). Content: label `bodySmall` top-left, `heroNumber` + unit `titleSmall`, one supporting line `body`. One ContourCard per screen max, first content element.

Driver uses: D2 sheet ("Route progress 4 of 9 wards") [p4,p5,p7,p14,p23,p24,p25,p26], D5 ("9 of 9 wards done Duration 5 h 12 min") [p12], On break card ("12:40 min") [p25].

### 4.12 Map layer components

| Component | Spec |
|---|---|
| Map tiles | `flutter_map` OSM tiles, attribution bottom-left (`attribution` style). Tint: light = multiply `brandSoft` at 35%; dark = invert matrix then multiply dark `surface` at 55% [inferred, D-108] |
| VanMarker | 44 dp circle, `brand` fill, 3 dp white ring, truck icon 24 white; hit area 48; moving = soft pulse ring 2400 ms; stale = `surfaceMuted` fill |
| EtaBubble | above marker; `surface`, radius 12, padding 8 x 12, `elev2`; text `label`: "12 min" or "Last seen 3 min ago" |
| Ward area | dashed 2 dp `brand` outline, 8% `brand` fill |
| Recenter button | AppIconButton 48 on map, bottom-right above sheet |

### 4.13 BottomSheet (draggable)

See 3.3. Content order: ContourCard -> primary actions -> secondary cards. Never nest scrolling inside collapsed sheet.

### 4.14 Modals

| Modal | Spec |
|---|---|
| ConfirmDialog | radius 28, `elev3`, title `title`, body `body`, buttons stacked full width (primary on top, `secondary` below) |
| MarkWardDoneConfirm | white rounded modal; title "Mark Ward 5 done?" `headline`; body "You seem far from this ward..." `body`; black pill "Mark done anyway"; white outline pill "Cancel" [from-wireframe:p6] |
| SkipWardModal | title "Skip Ward 5"; radio reasons ("Road is blocked", "No waste to collect", "Vehicle problem", "Other"); black pill "Skip Ward 5" [from-wireframe:p24] |
| CallForHelpModal | title "Call for help"; rows: "Ward inspector [phone number]" + phone icon button, "Office [phone number]" + phone icon button [from-wireframe:p26] |

### 4.15 Banners and feedback

| Component | Spec |
|---|---|
| OfflineBanner | pill under glass bar: `surfaceMuted`, `cloud_off` icon + "You are offline. Location will sync later." [from-wireframe:p5] |
| StaleBanner | same style, `schedule` icon, "Van location may be old" |
| SnackBar | floating, pill, `primary` fill, `onPrimary` text, 4 s, one optional text action |
| InlineError | `error` icon 20 + `bodySmall` `error` text under the field |

### 4.16 Empty / loading components (Binny removed [removed-T8])

| Component | Spec |
|---|---|
| EmptyState | centered column: neutral icon 96 dp in `brandSoft` circle (replaces Binny `wait`) + `title` + `body` muted + optional `primary`/`tonal` button |
| Skeleton | `surfaceMuted` rounded blocks matching the real layout, shimmer 1200 ms |
| Spinner | 20 dp inside buttons; 32 dp centered for full-screen loads |

Empty-state replacement rule: wherever DESIGN.md specifies Binny `wait` (empty Notices, empty Pending Reports, empty Trip history), the driver app shows a neutral icon (truck outline or ward outline) in a 96 dp `brandSoft` circle, title, body, and optional action. No mascot anywhere [removed-T8].

### 4.17 Language toggle (driver)

48 dp pill-shaped segmented control: two segments "ગુ" and "EN", selected segment = `primary` fill with `onPrimary` text. Visible on glass bar (D2), first-run, Settings [from-wireframe:p21].

### 4.18 Permission prompt screen

M3 shell. No Binny [removed-T8]. Icon circle 96 dp `brandSoft` fill with relevant icon (location p1, bell p15, battery p16). Title `headline`, body `body`, `primary` "Allow →" / "Open settings →", `text` "Not now" / "Later". Denied state: Info card with reason + "Open settings" `tonal` button. Top-end, beside the round close button: the app's shared `LanguageToggleButton` (reuse, no new component) so the driver can switch language mid-setup; it stays secondary, the screen keeps exactly one primary (CL-D07).

### 4.19 Welcome-back card [new]

White card radius 28, padding 20, shown on the Start Shift screen for returning devices. Contains: greeting ("Welcome back"), driver name, van, and route summary; optional "Change code" `text` link.

### 4.20 Confirm card [new]

See 4.10 Confirm card. Shown between code entry and Start Shift CTA. Displays: driver name, van number, ward count, masked phone number. Each row: leading icon 20 + label `titleSmall` + value `body`.

---

## 5. CONSISTENCY LAW (testable; cite by ID)

| ID | Rule |
|---|---|
| CL-D01 | Colors ONLY via `context.colors`. No raw `Color(0x...)` outside `app_colors.dart` and `ContourPainter` |
| CL-D02 | Spacing ONLY via `AppSpace`. No numeric margin/padding literals except `0` |
| CL-D03 | Radius ONLY via `AppRadius` |
| CL-D04 | Text ONLY via `context.text` styles. No inline `fontSize` or `fontWeight` |
| CL-D05 | No informational text below 14 sp. 12 sp only for map attribution and legal lines |
| CL-D06 | Every tappable at least 56 x 56 dp (driver app minimum) |
| CL-D07 | Exactly ONE `primary` (filled ink) button per screen |
| CL-D08 | The primary CTA is a full-width pill: pinned at the bottom in M3, inside the sheet in M1 |
| CL-D09 | Status is ALWAYS color + icon + label, rendered only by `StatusChip` (or `ComplaintPin` on maps) |
| CL-D10 | `error` color is for validation and failure messages only |
| CL-D11 | Orange: fills carry ink text; orange text or orange behind white text MUST use `accentStrong`. NEVER white on `accent` |
| CL-D12 | The ContourCard is the ONLY top status element for: route progress (D2), shift summary (D5), on-break time (On break). NEVER replace it |
| CL-D13 | Maximum one ContourCard per screen, always the first content element |
| CL-D14 | `brandMid` and `brandLeaf` NEVER carry text other than ink |
| CL-D15 | Binny NEVER appears on any driver screen [removed-T8]. Empty states use a neutral icon in a `brandSoft` circle |
| CL-D16 | Cards: radius 28, no border. Inputs: radius 20 with 1.5 dp `borderStrong` outline. Chips, buttons, nav: pill |
| CL-D17 | Shadows ONLY from `elev1` to `elev3`. `surfaceTintColor: Colors.transparent` on Material surfaces |
| CL-D18 | Glass bar opacity >= 80%; text on it uses `textPrimary` |
| CL-D19 | Icons: Material Symbols Outlined, 24 dp (20 inside chips), weight 300 |
| CL-D20 | No widget branches on `Brightness` for color |
| CL-D21 | All strings from localization (`gu`, `en`). Layouts MUST survive strings 150% longer than English |
| CL-D22 | Language toggle reachable in at most 1 tap from D2 glass bar, and always present in Settings |
| CL-D23 | Every screen implements loading, empty, error and offline states |
| CL-D24 | Every tappable has a `Semantics` label in the active language |
| CL-D25 | No horizontal scrolling of page content (map is the only pan surface) |
| CL-D26 | Driver app uses driver sizes everywhere (56/64/72/80); never mixed with user sizes |
| CL-D27 | Map camera padding accounts for sheet and nav so the van marker is never hidden |
| CL-D28 | No raw exception text, stack traces or error codes to the user |
| CL-D29 | Every tappable defines the pressed state from 4.0 |
| CL-D30 | Lists separated by 12 dp gaps, never divider lines |
| CL-D31 | One font family (Noto Sans + Gujarati fallback), weights 300 to 600 only |

---

## 6. DECISION MATRICES

### DM-D01 Content -> component (driver)

| Content | Component |
|---|---|
| Route progress / wards done / break time | ContourCard |
| Ward completion list | WardRow |
| Choose 1 of 2-5 options | AppChip row |
| Short free text (code XX-0000) | CodeField |
| Message from admin | Notice card |
| Instructional text | Info card |
| Shift summary | ContourCard + End Shift CTA |
| Confirmation before destructive action | ConfirmDialog |

### DM-D02 Field count -> form layout (driver)

| Fields | Layout |
|---|---|
| 1 (code) | CodeField inside M3 body, 16 dp gaps |
| 2-4 | M3 shell, stacked, 16 dp gaps |
| 5+ | not expected; split into M3 steps |

### DM-D03 Severity -> pattern (driver states)

| Situation | Pattern |
|---|---|
| Neutral info | Info card |
| Success (shift ended, ward done) | ContourCard + SnackBar for minor actions |
| Warning (stale, offline, location off) | banner under glass bar |
| Recoverable error (wrong PIN, write failed) | InlineError + "Try again" `tonal` button |
| Blocking error (cannot load app data) | full-screen error: icon in `brandSoft` circle, `title`, `body`, `primary` "Try again". No mascot |
| Destructive (end shift, skip ward) | ConfirmDialog (stacked buttons) |

### DM-D04 State -> UI (driver)

| State | UI |
|---|---|
| Loading | Skeleton matching final layout |
| Empty | EmptyState: neutral icon + title + body + optional action |
| Error | DM-D03 |
| Offline | OfflineBanner under glass bar; queued items show `queued` chip |
| Stale data | StaleBanner + muted marker |
| Success | ContourCard showing result |

### DM-D05 Intent -> CTA hierarchy (driver)

| Intent | Variant |
|---|---|
| The one main task on the screen | `primary` |
| A second valid path | `secondary` |
| Safe, low-emphasis (Later, Open settings) | `tonal` |
| Skip / later / inline link (Change code) | `text` |

---

## 7. STATES AND FEEDBACK

### 7.1 Validation timing (driver)

| Context | When | How |
|---|---|---|
| Code field (XX-0000) | on submit (Start Shift tap) | inline `error` outline + InlineError: "Wrong code. Try again." |
| Code field format | on input | auto-format hyphen after 2 chars; reject non-numeric |
| Location unavailable | at shift start | block with Info card + "Turn on location" `tonal` button |
| Write failed (mark ward done) | on write failure | revert WardRow, SnackBar with "Try again" |

### 7.2 Copy patterns (all strings in `gu` and `en`)

- Sentence case. Max 12 words per message. No jargon, no codes, no exclamation marks except success.
- Pattern: what happened + what to do. Example: "Wrong code. Try again."
- Buttons: verb + noun, max 3 words ("Start Shift", "Mark done anyway", "Back to start").
- String keys: `area.screen.element` (example `shift.start.startShift`).
- Success titles: "Sent", "Done", "Thank you" only.

Wireframe exact strings (en):

| Screen | Title | Body | Buttons |
|---|---|---|---|
| Permission 1 | Allow location all the time | The app shares your van's position while your shift is on, even when the screen is off. You can stop it any time by ending the shift. | Allow, Not now |
| Permission 2 | Allow notifications | Get messages from the office and route changes, even when the app is closed. | Allow, Not now |
| Permission 3 | Keep tracking running | Turn off battery saving for this app so tracking does not stop when the screen is off. | Open settings, Later |
| Start Shift | Start shift | Van: GJ-17-1234; Route: East route (set by admin); PIN: • • • • | Start Shift |
| Start Shift error | Start shift | Wrong PIN. Try again. | Start Shift |
| D2 Live Route | East route | Tracking active; Van GJ-17-1234 | Mark Ward Done: Ward 5 |
| D2 offline | East route | You are offline. Location will sync later. | (none) |
| Mark done confirm | Mark Ward 5 done? | You seem far from this ward. It will be marked done and flagged for review. | Mark done anyway, Cancel |
| Notices | Notices | (list with timestamps) | (none) |
| Notices empty | Notices | No notices. New messages from the office will show here. | (none) |
| Pending Reports | Pending Reports | (list with Received pills) | Will revisit, Done |
| Pending Reports empty | Pending Reports | All caught up. No missed-collection reports on your route. | (none) |
| End Shift | End Shift | Shift summary. 9 of 9 wards done. Duration 5 h 12 min. GPS tracking will stop when you end the shift. | End Shift |
| Shift ended | Shift ended | Great work today. GPS tracking has stopped. Wards done: 9 of 9 · 5 h 12 min | Back to start |
| Location is off | Location is off | Citizens cannot see your van until location is on. | Turn on location |
| Session ended | Session ended | Enter your PIN again to continue. Your trip is saved. | Enter PIN |
| Route change tomorrow | Route change tomorrow | Ward 7 is added to the East route from Monday. Start with Ward 5 as usual and finish at Ward 7. Call the office if the order looks wrong. | Got it |
| Report detail | Missed collection · Ward 5 | 3 reports today · 25 min ago | Done ✓, Will revisit |
| Settings | Settings | Language: ગુજરાતી / EN; Theme: Light / Dark / System; Van: GJ-17-1234 · East route | Trip history →, Help and about → |
| Trip history | Trip history | Today/Yesterday/22 Oct with wards done and duration | (none) |
| More options | More options | Pause shift, Skip this ward, Call for help, Settings, End shift | (none) |
| Skip Ward | Skip Ward 5 | Road is blocked / No waste to collect / Vehicle problem / Other | Skip Ward 5 |
| On break | On break | Break time 12:40 min. Citizens see: van on break. GPS stays on while you rest. | Resume Shift |
| Call for help | Call for help | Ward inspector [phone number]; Office [phone number] | (phone buttons) |

Gujarati equivalents are stored in `app_gu.arb`; layouts must survive 150% longer strings (CL-D21).

### 7.3 Offline behaviour

Show OfflineBanner under the glass bar. Shift data queues locally and syncs on reconnect. Map shows last known van position with stale rule. Never block the UI because of network loss.

### 7.4 Permissions

Ask only when needed, with the rationale screen (4.18) first. Denied once: Info card on the feature screen + "Open settings" `tonal` button. The app MUST remain usable without notifications. Location is required for shift tracking; fall back to manual ward picker if denied.

---

## 8. MOTION

| Element | Motion | Duration | Curve |
|---|---|---|---|
| Screen transition (push) | fade + slide up 24 dp | 200 ms | `standard` |
| Screen transition (pop) | fade | 120 ms | `exit` |
| Sheet snap | position | 320 ms | `standard` |
| Nav active circle | slide + color | 200 ms | `standard` |
| Button / card press | scale to 0.98 | 120 ms | `standard` |
| Chip select | color cross-fade | 120 ms | `standard` |
| Van marker position | tween between GPS updates | 1000 ms | linear |
| Van pulse ring | scale 1 -> 1.8, fade out, repeat | 2000 ms | `standard` |
| SnackBar | slide up | 200 ms | `standard` |
| Skeleton shimmer | gradient sweep | 1200 ms | linear |

Forbidden: bounce or elastic curves, parallax, confetti, shake, auto-playing loops other than the table above, any non-ambient animation longer than 400 ms, spinners larger than 32 dp.

Reduced motion (`MediaQuery.disableAnimations`): all durations become 0 except a 120 ms fade; stop the pulse ring and shimmer (show static versions).

---

## 9. PAGE TEMPLATES

Legend: `[...]` button, `(...)` icon button, `<...>` component. Tags: `[from-wireframe:pN]`, `[new]`, `[modified]`, `[removed-T8]`.

### 9.1 Splash (M5) `[from-image:2]`

```
+--------------------------------+
|  brandMid background + blob    |
|                                |
|       <neutral icon, 220>      |  [removed-T8: no Binny]
|                                |
|  Safai Sathi        (display)  |
|  Driver app          (body,ink) |
|                                |
|  [ Get Started            -> ] |  primary, bottom
+--------------------------------+
```

### 9.2 Welcome (fresh device) (M3) `[new]`

```
+--------------------------------+
|  Welcome               (headline)|
|                                |
|  Start your first shift        |
|  in a few quick steps.  (body)   |
|                                |
|  [ Continue            -> ] |  primary, bottom
+--------------------------------+
```

### 9.3 Permission Screen 1 — Allow location all the time (M3) `[from-wireframe:p1]`

```
+--------------------------------+
|  ( ) ( )   3-dot step indicator|
|                                |
|   <location icon, 96>          |  brandSoft circle
|                                |
|  Allow location all the time   |  headline
|                                |
|  The app shares your van's     |
|  position while your shift is  |
|  on, even when the screen is   |
|  off. You can stop it any time |
|  by ending the shift.   (body) |
|                                |
|  [ Allow              -> ] |  primary, bottom
|  Not now                          |  text, green
+--------------------------------+
```

### 9.4 Permission Screen 2 — Allow notifications (M3) `[from-wireframe:p15]`

```
+--------------------------------+
|  ( )( )   3-dot step indicator |
|                                |
|   <bell icon, 96>              |  brandSoft circle
|                                |
|  Allow notifications           |  headline
|                                |
|  Get messages from the office  |
|  and route changes, even when  |
|  the app is closed.     (body) |
|                                |
|  [ Allow              -> ] |  primary
|  Not now                          |  text, green
+--------------------------------+
```

### 9.5 Permission Screen 3 — Keep tracking running (battery) (M3) `[from-wireframe:p16]`

```
+--------------------------------+
|  ( )   3-dot step indicator    |
|                                |
|   <battery icon, 96>           |  brandSoft circle
|                                |
|  Keep tracking running         |  headline
|                                |
|  Turn off battery saving for   |
|  this app so tracking does not |
|  stop when the screen is off. (body)
|                                |
|  [ Open settings     -> ] |  primary
|  Later                              |  text, green
+--------------------------------+
```

### 9.6 Start Shift — code entry (modified from van + PIN) `[modified]`

```
+--------------------------------+
|  Start shift           (headline)|
|                                |
|  Code                   (label)  |
|  [ XX-0000             ]         |  CodeField, height 64
|                                |
|  <Confirm card:          >       |  [new], white card radius 28
|  Name:    Driver Name            |
|  Van:     GJ-17-1234             |
|  Wards:   9                      |
|  Phone:   +91-XXXX-XXXX12        |
|                                |
|  [ Start Shift       -> ] |  primary, height 64, bottom
+--------------------------------+
```

### 9.7 Start Shift — Wrong PIN error state (kept pattern for code validation) `[from-wireframe:p3]`

```
+--------------------------------+
|  Start shift           (headline)|
|                                |
|  Code                   (label)  |
|  [ XX-0000             ]         |  outline error, all boxes red
|  ! Wrong code. Try again.   (InlineError)
|                                |
|  [ Start Shift       -> ] |  primary, bottom
+--------------------------------+
```

### 9.8 D2 Live Route — default / tracking active (M1, driver sizes) `[from-wireframe:p4,p5,p7,p14]`

```
+--------------------------------+
| <GlassBar> route + TrackingBadge (settings) |
| <OfflineBanner / stale / mock-location> |
|                                |
|          MAP                   |
|     <VanMarker> <Ward areas>   |
|     <UserLocation>             |
|                          (⌖)   |
|==== sheet, snap 0.36 ==========|
|  ----                          |
|  <ContourCard>                 |
|   Route progress               |
|   4 of 9 wards          (hero) |
|  [ Mark Ward Done: Ward 5 ] |  BigActionButton 72 high
|  <WardRow> Ward 4 Done · 09:42 |
|  <WardRow> Ward 5 Next stop    |
|       <PillNav driver>         |
+--------------------------------+
```
BigActionButton label swaps to "End Shift" once every ward is done (opens D5). Landscape: map left (60%), panel right (40%, max 420) holding ContourCard + BigActionButton + ward list; nav pill stays bottom-left.

### 9.9 D2 Live Route — offline state `[from-wireframe:p5]`

Same as 9.8, plus OfflineBanner under the glass bar: `cloud_off` icon + "You are offline. Location will sync later."

### 9.10 Mark Ward Done confirm modal `[from-wireframe:p6]`

```
+---------------------------+
|  Mark Ward 5 done?   (headline)
|                           |
|  You seem far from this   |
|  ward. It will be marked  |
|  done and flagged for     |
|  review.         (body)   |
|                           |
|  [ Mark done anyway ] |  primary
|  [ Cancel          ] |  secondary outline
+---------------------------+
```

### 9.11 Notices — with notices (M2) `[from-wireframe:p8]`

```
+--------------------------------+
|  Notices             (display) |
|                                |
|  <Notice card> Route change    |  orange left bar if unread
|  tomorrow                      |
|  Ward 7 is added...   (body)   |
|  10 min ago           (muted)  |
|                                |
|  <Notice card> ...             |
|       <PillNav driver>         |
+--------------------------------+
```
Badge "2" on bell icon in pill nav (unread count).

### 9.12 Notices — empty state (M2) `[from-wireframe:p9] [removed-T8]`

```
+--------------------------------+
|  Notices             (display) |
|                                |
|       <neutral icon, 96>       |  brandSoft circle, [removed-T8: no Binny]
|                                |
|  No notices             (title) |
|  New messages from the office  |
|  will show here.      (body)   |
|       <PillNav driver>         |
+--------------------------------+
```

### 9.13 Pending Reports — with reports (M2) `[from-wireframe:p10]`

```
+--------------------------------+
|  Pending Reports     (display) |
|                                |
|  <Card> Missed collection ·    |
|  Ward 5                 (title)|
|  3 reports today · 25 min ago  |
|  <StatusChip> Received         |
|  [ Will revisit ] [ Done ]     |  tonal pills
|                                |
|  <Card> ...                    |
|       <PillNav driver>         |
+--------------------------------+
```

### 9.14 Pending Reports — empty state (M2) `[from-wireframe:p11] [removed-T8]`

```
+--------------------------------+
|  Pending Reports   (display)   |
|                                |
|       <neutral icon, 96>       |  brandSoft circle
|                                |
|  All caught up          (title)|
|  No missed-collection reports  |
|  on your route.         (body) |
|       <PillNav driver>         |
+--------------------------------+
```

### 9.15 End Shift — shift summary (M3) `[from-wireframe:p12]`

```
+--------------------------------+
|  End Shift           (headline)|
|                                |
|  <ContourCard>                 |
|   Shift summary                |
|   9 of 9 wards done      (hero)|
|   Duration 5 h 12 min          |
|                                |
|  ! GPS tracking will stop when |
|  you end the shift.   (info)   |
|                                |
|  [ End Shift           -> ] |  primary, bottom
+--------------------------------+
```

### 9.16 Shift ended — confirmation (M3) `[from-wireframe:p13] [removed-T8]`

```
+--------------------------------+
|  Shift ended         (headline)|
|                                |
|       <neutral icon, 160>      |  brandSoft circle, [removed-T8: no Binny]
|                                |
|  Great work today. GPS         |
|  tracking has stopped.  (body) |
|                                |
|  <Card> Wards done             |
|   9 of 9 · 5 h 12 min          |
|                                |
|  [ Back to start     -> ] |  primary, bottom
+--------------------------------+
```

### 9.17 Location is off — warning (M3) `[from-wireframe:p17]`

```
+--------------------------------+
|       <location icon, 96>      |  orange circle
|                                |
|  Location is off         (headline)|
|                                |
|  Citizens cannot see your van  |
|  until location is on.   (body)|
|                                |
|  [ Turn on location  -> ] |  primary, bottom
+--------------------------------+
```

### 9.18 Session ended — re-auth gate (M3) `[from-wireframe:p18]`

```
+--------------------------------+
|       <! icon, 96>             |  orange circle
|                                |
|  Session ended         (headline)|
|                                |
|  Enter your PIN again to       |
|  continue. Your trip is saved. (body)
|                                |
|  [ Enter PIN         -> ] |  primary, bottom
+--------------------------------+
```

### 9.19 Route change tomorrow — banner modal `[from-wireframe:p19]`

```
+--------------------------------+
|  (<)   Route change tomorrow   |
|  10 min ago           (muted)  |
|                                |
|  Ward 7 is added to the East   |
|  route from Monday. Start with |
|  Ward 5 as usual and finish at |
|  Ward 7. Call the office if    |
|  the order looks wrong. (body) |
|                                |
|  <Applies to East route>   (chip)|
|                                |
|  [ Got it            -> ] |  primary, bottom
+--------------------------------+
```

### 9.20 Report detail modal (M4) `[from-wireframe:p20]`

```
+--------------------------------+
|  (<)   PMH-20261024-0412       |
|                                |
|  <map with orange pin>         |
|                                |
|  Missed collection · Ward 5    |
|  3 reports today · 25 min ago  |
|                                |
|  [ Done ✓          ] |  primary
|  [ Will revisit    ] |  secondary outline
+--------------------------------+
```

### 9.21 Settings screen (M2) `[from-wireframe:p21]`

```
+--------------------------------+
|  Settings            (display) |
|                                |
|  <Card> Language   [ગુ|EN]     |  segmented toggle
|  <Card> Theme    [Light|Dark|System]
|  <Card> Van        GJ-17-1234  |
|                      · East route|
|  <Card> Trip history           |  (>) arrow
|  <Card> Help and about         |  (>) arrow
|       <PillNav driver>         |
+--------------------------------+
```

### 9.22 Trip history screen (M2) `[from-wireframe:p22]`

```
+--------------------------------+
|  Trip history        (display) |
|                                |
|  <Card> Today                  |
|  9 of 9 wards · 5 h 12 min     |
|  <StatusChip> Completed        |
|                                |
|  <Card> Yesterday              |
|  9 of 9 wards · 5 h 40 min     |
|  <StatusChip> Completed        |
|                                |
|  <Card> 22 Oct                 |
|  7 of 9 wards · 4 h 05 min     |
|  <StatusChip> Partly done      |
|       <PillNav driver>         |
+--------------------------------+
```

### 9.23 More options menu (sheet) `[from-wireframe:p23]`

```
+---------------------------+
|  More options       (headline)
|                           |
|  (pause)  Pause shift     |
|  (skip)   Skip this ward  |
|  (phone)  Call for help   |
|  (setup)  Settings        |
|  (end)    End shift       |  error color + icon
+---------------------------+
```

### 9.24 Skip Ward modal `[from-wireframe:p24]`

```
+---------------------------+
|  Skip Ward 5        (headline)
|                           |
|  (●) Road is blocked      |
|  ( ) No waste to collect  |
|  ( ) Vehicle problem      |
|  ( ) Other                |
|                           |
|  [ Skip Ward 5    -> ] |  primary, bottom
+---------------------------+
```

### 9.25 On break screen (M3) `[from-wireframe:p25]`

```
+--------------------------------+
|  On break            (headline)|
|                                |
|  <ContourCard>                 |
|   Break time                   |
|   12:40 min             (hero) |
|   Citizens see: van on break   |
|                                |
|  ! GPS stays on while you rest. (info)
|                                |
|  [ Resume Shift      -> ] |  primary, bottom
+--------------------------------+
```

### 9.26 Call for help modal `[from-wireframe:p26]`

```
+---------------------------+
|  Call for help      (headline)
|                           |
|  Ward inspector     (title) |
|  [phone number]       (muted)   [📞]
|  Office             (title)   |
|  [phone number]       (muted)   [📞]
+---------------------------+
```

### 9.27 Welcome-back card (returning device) on Start Shift `[new]`

Shown on the Start Shift screen when the device is returning. Inserted above the code field:

```
+---------------------------+
|  Welcome back, Driver     |  headline
|  Van: GJ-17-1234   Route: |  body
|  East route               |
|  Change code          (>) |  text link
+---------------------------+
```





