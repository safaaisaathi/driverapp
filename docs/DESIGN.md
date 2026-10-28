# DESIGN.md: Safai Sathi Design System v1.0 (working name)

```
AUDIENCE    : AI coding agent (machine-parsed). Human readability is secondary.
PARSE MODE  : literal. MUST/NEVER/ALWAYS = hard rule. No rule is optional unless marked [optional].
STACK       : Flutter (stable) + Material 3 (heavily themed) + Riverpod + flutter_map + flutter_svg + Noto Sans / Noto Sans Gujarati (bundled)
SCOPE       : User app (citizen) and Driver app. Admin web panel is OUT OF SCOPE here; it gets its own file later and MUST reuse the token names in Section 2.
THEMES      : light [from-image] + dark [inferred]
SOURCE      : two reference images. Image 1 = glassy map-first air-quality app (layout). Image 2 = flat green waste-management illustration app (palette, buttons, illustration style).
CONTRACT    : Token names in PRD section 0.5 (color.primary, color.onPrimary, color.background, color.surface, color.textPrimary, color.textMuted, color.status*, radius.md, spacing.unit) are KEPT. Values are overridden by this file. See D-02.
```

## TAG LEGEND

| Tag | Meaning |
|---|---|
| `[from-image:1]` / `[from-image:2]` | Directly visible in reference image 1 or 2 |
| `[est]` | Visible but value estimated; snapped to the 4 dp grid. Correct in Section 2 only |
| `[inferred]` | NOT in the images; derived from tokens and personality. Same rules, lower confidence |

## AUTHORITY ORDER (on conflict, higher wins)

1. Section 5 (Consistency Law)
2. Section 2 (Tokens)
3. Section 15 (Content Organization)
4. Section 4 (Component specs)
5. Section 9 (Page templates)
6. Agent judgment (only when 1-5 are silent; then match Section 0 attributes and add the new rule to this file)

All product behaviour (screens, data, flows) comes from PRD-1 (user app) and PRD-2 (driver app). This file decides only how things look and where they go.

---

## 0. META

| Field | Value |
|---|---|
| Name | Safai Sathi (working name, replace freely) |
| Product type | Two Flutter mobile apps: citizen app (live van map, photo complaints) and driver app (GPS shift tracking). [from PRD] |
| Accent policy | Brand = green family. ONE accent hue (orange) for selection and attention only: selected chip, location pin, "needs attention" highlights. Ink (near-black) is the primary action color |
| Signature | **Contour card**: a large rounded card filled with topographic contour lines (Section 4.9). Used for the single most important status on a screen |
| Mascot | **Binny**, a friendly dustbin with a leaf sprout (Section 4.20). Only on splash, empty and success screens |

| Attribute | Value | Numeric backing |
|---|---|---|
| corner-radius | very large | cards 28 dp, sheets 32 dp, inputs 20 dp, buttons/chips/nav full (999) |
| density | roomy | control height 56 dp (driver 56, user 52 minimum 48), card padding 20 dp, page padding 20 dp |
| contrast | strict AA | body text >= 4.5:1, UI shapes >= 3:1 (Appendix D) |
| motion | calm | 120-320 ms, ease-out, no bounce, no parallax |
| depth | soft | cards flat on tinted page; floating layers (nav pill, glass bar, sheets) use soft shadow |
| iconography | thin outline | Material Symbols Outlined (rounded), 24 dp, weight 300, grade 0 |
| whitespace | generous | card gap 12 dp, section gap 24 dp |
| alignment | left aligned text; primary action centered at the bottom | CTA is a full-width black pill |
| language | bilingual | Gujarati + English, toggle always reachable; strings never hardcoded |

### Decision log (agent MUST honor)

| ID | Decision | Reason |
|---|---|---|
| D-01 | The web blueprint is adapted to Flutter. Section 4 uses widget specs instead of CSS/Tailwind class strings. Sections 2, 3, 5-12, 14, 15 are kept | Platform (Flutter) |
| D-02 | `color.primary` in PRD 0.5 was a placeholder green. This file redefines it: **`color.primary` = ink (near-black)**, the primary action color, as in image 2's black pill buttons. The brand green moves to a new token `color.brand`. Dark theme inverts: primary = near-white | Matches image; PRD names stay valid |
| D-03 | Image orange `#F0873A` with white text is 2.55:1 (fails AA). Rule: orange FILLS carry INK text (6.97:1). Orange TEXT or orange fill with WHITE text MUST use `color.accentStrong` `#B34A0B` (5.38:1) | AA strict (chosen) |
| D-04 | Image 1's lime accent is NOT used. Its role is taken by brand green. Lime appears nowhere | Blend chosen: image 2 palette |
| D-05 | Image 1's contour-line card is kept as the signature element, recolored in green tints | Layout from image 1 |
| D-06 | Mascot is named Binny (working name). Appears only on splash, empty and success screens. NEVER on error, destructive or permission-denied screens | Chosen rule |
| D-07 | Dark theme is a full second theme from the same variables. Widgets MUST NOT branch on brightness for color; they read `AppColors` | Single source of truth |
| D-08 | `color.brandMid` `#6DB36F` and `color.brandLeaf` `#B5CF8A` never carry text of any size (white on brandMid is 2.52:1). Only ink text sits on them | AA |
| D-09 | Fonts are bundled as assets (offline-safe for rural users). NEVER fetch fonts at runtime. Gujarati text uses `height: 1.5` | Connectivity and glyph height |
| D-10 | Minimum touch target 48 dp (driver app 56 dp). Informational text >= 14 sp (12 sp only for map attribution and legal lines). Status is ALWAYS color + icon + label | Chosen fixed rules |
| D-11 | The report flow has NO gallery/picker UI. Camera capture only | PRD + chosen rule |
| D-12 | Map tiles are OSM raster tiles. They are tinted with a ColorFilter to match the theme. If the tinted result looks wrong on device, fall back to untinted tiles and keep the glass overlays | `[inferred]` |
| D-13 | Admin web panel excluded. When it is designed later it MUST reuse Section 2 names as CSS variables (`--color-primary`, `--color-brand`, ...) | Chosen scope |
| D-14 | Mascot image assets are SVG files in `assets/mascot/` (`binny-wave`, `binny-wait`, `binny-celebrate`, `binny-sleep`). Do not redraw them | Consistency |

---

## 1. DESIGN DNA (extracted from images)

| Attribute | Value | Confidence |
|---|---|---|
| Layout archetype | Map-first home with a floating glass top bar, floating pill bottom nav, and a draggable rounded sheet of cards `[from-image:1]` | high |
| Alternative layout | Card-list screens: large light title, stacked rounded cards `[from-image:1]` | high |
| Flow/onboarding layout | Full-bleed green screen with organic leaf blob, illustration, big black pill CTA `[from-image:2]` | high |
| Page background (light) | light grey-green `#F3F6F2` | med `[est]` (image 1 grey `#E9EAEC`, tinted green) |
| Card surface | white `#FFFFFF`, no border, soft shadow | high |
| Brand green | dark `#1B7A3F`, mid `#6DB36F`, leaf `#B5CF8A` | med `[est]` `[from-image:2]` |
| Accent | orange `#F0873A` for the selected chip and the location pin | med `[est]` `[from-image:2]` |
| Ink | `#111A14` (image `#111111`, nudged green) | med `[est]` |
| Map (dark) | navy-slate `#2B3F55` with lighter roads `[from-image:1]`; app map is tinted green-grey instead | med |
| Font | geometric sans, light-weight large headings (Manrope/Satoshi-like). Mapped to Noto Sans | low `[est]` |
| Heading scale | hero number 56, display 36 light, body 16 | med `[est]` |
| Radius | cards ~28, sheet top ~32, inputs ~pill, buttons pill | high |
| Buttons | black full-width pill, white 16 dp semibold label, trailing icon `[from-image:2]` | high |
| Chips | small pills; selected = orange fill, ink text `[from-image:2]` | high |
| Navigation | white floating pill with two round slots; active slot = black circle with white icon `[from-image:1]` | high |
| Top bar | translucent glass pill with place avatar, two-line title (name + subtitle), round icon buttons `[from-image:1]` | high |
| Small stat tiles | rounded tile, label top-left, round arrow button top-right, big number, faint dot texture `[from-image:1]` | high |
| Signature pattern | contour-line card, lines in a tint of the card color `[from-image:1]` | high |
| Camera frame | four corner brackets, rounded, white, over the preview `[from-image:2]` | high |
| Illustration | flat vector, thick dark-green outlines, leaf shapes, orange details `[from-image:2]` | high |
| Icons | thin outline, in a 48 dp circle for header buttons `[from-image:1]` | med |
| Not in images | dark theme, driver app, forms, errors, empty/loading states, Gujarati text, complaint list/detail | n/a, `[inferred]` |

---

## 2. DESIGN TOKENS

### 2.1 Color tokens: `lib/core/theme/app_colors.dart` (COPY VERBATIM)

```dart
import 'package:flutter/material.dart';

@immutable
class StatusStyle {
  const StatusStyle({required this.fill, required this.soft, required this.text});
  final Color fill;  // pins, dots, icons on neutral surfaces (3:1 vs surface)
  final Color soft;  // chip background
  final Color text;  // chip label and icon on soft (>= 4.5:1)
}

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background, required this.surface, required this.surfaceMuted,
    required this.border, required this.borderStrong,
    required this.textPrimary, required this.textMuted,
    required this.primary, required this.onPrimary,
    required this.brand, required this.onBrand, required this.brandSoft,
    required this.brandMid, required this.brandLeaf,
    required this.accent, required this.onAccent, required this.accentStrong, required this.accentSoft,
    required this.error, required this.scrim,
    required this.statusReceived, required this.statusAssigned,
    required this.statusResolved, required this.statusEscalated,
  });

  final Color background, surface, surfaceMuted, border, borderStrong;
  final Color textPrimary, textMuted;
  final Color primary, onPrimary;              // PRD token names kept. primary = INK (D-02)
  final Color brand, onBrand, brandSoft, brandMid, brandLeaf;
  final Color accent, onAccent, accentStrong, accentSoft;
  final Color error, scrim;
  final StatusStyle statusReceived, statusAssigned, statusResolved, statusEscalated;

  static const light = AppColors(
    background: Color(0xFFF3F6F2), surface: Color(0xFFFFFFFF), surfaceMuted: Color(0xFFE9F1E6),
    border: Color(0xFFDCE5D9), borderStrong: Color(0xFF74897A),
    textPrimary: Color(0xFF14201A), textMuted: Color(0xFF566259),
    primary: Color(0xFF111A14), onPrimary: Color(0xFFFFFFFF),
    brand: Color(0xFF1B7A3F), onBrand: Color(0xFFFFFFFF), brandSoft: Color(0xFFE4F1DF),
    brandMid: Color(0xFF6DB36F), brandLeaf: Color(0xFFB5CF8A),
    accent: Color(0xFFF0873A), onAccent: Color(0xFF111A14),
    accentStrong: Color(0xFFB34A0B), accentSoft: Color(0xFFFFEBD9),
    error: Color(0xFFB3261E), scrim: Color(0x66111A14),
    statusReceived: StatusStyle(fill: Color(0xFFB87800), soft: Color(0xFFFFF1D1), text: Color(0xFF8A5A00)),
    statusAssigned: StatusStyle(fill: Color(0xFF2F6FDE), soft: Color(0xFFE3EDFF), text: Color(0xFF1D4FB8)),
    statusResolved: StatusStyle(fill: Color(0xFF1E8E5A), soft: Color(0xFFDDF3E4), text: Color(0xFF146B3A)),
    statusEscalated: StatusStyle(fill: Color(0xFFD93025), soft: Color(0xFFFDE3E0), text: Color(0xFFB3261E)),
  );

  static const dark = AppColors(
    background: Color(0xFF0E1612), surface: Color(0xFF16221B), surfaceMuted: Color(0xFF1E2D24),
    border: Color(0xFF2A3B31), borderStrong: Color(0xFF5F7A68),
    textPrimary: Color(0xFFEAF2E6), textMuted: Color(0xFF9DB0A2),
    primary: Color(0xFFF2F7EE), onPrimary: Color(0xFF0E1612),
    brand: Color(0xFF6DB36F), onBrand: Color(0xFF0E1612), brandSoft: Color(0xFF1F3A2A),
    brandMid: Color(0xFF6DB36F), brandLeaf: Color(0xFFB5CF8A),
    accent: Color(0xFFF0873A), onAccent: Color(0xFF111A14),
    accentStrong: Color(0xFFF5A15F), accentSoft: Color(0xFF3A2414),
    error: Color(0xFFFF9B91), scrim: Color(0x99000000),
    statusReceived: StatusStyle(fill: Color(0xFFF2A100), soft: Color(0xFF3A2E0E), text: Color(0xFFF7C85A)),
    statusAssigned: StatusStyle(fill: Color(0xFF5B8FF0), soft: Color(0xFF1B2B4D), text: Color(0xFF8DB4FF)),
    statusResolved: StatusStyle(fill: Color(0xFF3FB27A), soft: Color(0xFF17382A), text: Color(0xFF7ED6A1)),
    statusEscalated: StatusStyle(fill: Color(0xFFF2685D), soft: Color(0xFF43201C), text: Color(0xFFFF9B91)),
  );

  @override AppColors copyWith() => this;                 // not used
  @override AppColors lerp(ThemeExtension<AppColors>? other, double t) =>
      other is AppColors ? (t < 0.5 ? this : other) : this; // themes switch instantly
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
```

PRD token to Dart mapping (names preserved):

| PRD 0.5 token | Dart | Light | Dark |
|---|---|---|---|
| `color.primary` | `colors.primary` | `#111A14` | `#F2F7EE` |
| `color.onPrimary` | `colors.onPrimary` | `#FFFFFF` | `#0E1612` |
| `color.background` | `colors.background` | `#F3F6F2` | `#0E1612` |
| `color.surface` | `colors.surface` | `#FFFFFF` | `#16221B` |
| `color.textPrimary` | `colors.textPrimary` | `#14201A` | `#EAF2E6` |
| `color.textMuted` | `colors.textMuted` | `#566259` | `#9DB0A2` |
| `color.statusReceived` / `Assigned` / `Resolved` / `Escalated` | `colors.status*` (`.fill`) | see code | see code |
| `radius.md` | `AppRadius.md` | 12 | 12 |
| `spacing.unit` | `AppSpace.unit` | 8 | 8 |
| (new) `color.brand` | `colors.brand` | `#1B7A3F` | `#6DB36F` |

Semantic roles (when to use which):

| Role | Token | Use |
|---|---|---|
| Primary action fill | `primary` + `onPrimary` | main CTA pill, active nav circle |
| Brand surface/emphasis | `brand`, `brandSoft`, `brandMid`, `brandLeaf` | splash background, contour card, van marker, links, success |
| Selection / attention | `accent` (fill, ink text), `accentStrong` (text), `accentSoft` | selected chip, location pin, "needs attention" row highlight |
| Page and cards | `background`, `surface`, `surfaceMuted` | page, card, inset area |
| Lines | `border` (decorative), `borderStrong` (input outline, 3:1) | dividers, input borders |
| Text | `textPrimary`, `textMuted` | all text |
| Errors | `error` | validation text and icon only. NEVER use for status "Escalated" |

### 2.2 Type: `lib/core/theme/app_text.dart`

Fonts (bundled in `assets/fonts/`, declared in `pubspec.yaml`): `NotoSans` (400, 500, 600, 300) and `NotoSansGujarati` (400, 500, 600). Every `TextStyle` sets `fontFamily: 'NotoSans'` and `fontFamilyFallback: ['NotoSansGujarati']`.

| Style | Size / line | Weight | Use |
|---|---|---|---|
| `heroNumber` | 56 / 60 | 400 | ETA minutes on the contour card |
| `display` | 36 / 44 | 300 | large screen titles (card-list shells) |
| `headline` | 28 / 36 | 500 | sheet titles, ward name |
| `title` | 20 / 30 | 600 | card titles |
| `titleSmall` | 16 / 24 | 600 | list item titles, stat labels |
| `body` | 16 / 24 | 400 | default text |
| `bodySmall` | 14 / 22 | 400 | secondary text (minimum for informational text) |
| `label` | 14 / 20 | 600 | chips, nav labels, status chips |
| `button` | 16 / 24 | 600 | all buttons |
| `attribution` | 12 / 16 | 400 | ONLY map attribution and legal lines |

Rules: Gujarati strings use line height >= 1.5 x size (the table values already do). Never use a size below 14 except `attribution`. Never use weight 700 or above. Numbers in `heroNumber` use tabular figures (`FontFeature.tabularFigures()`).

### 2.3 Space, radius, elevation, sizes: `lib/core/theme/app_tokens.dart`

```dart
class AppSpace {            // 4 dp grid
  static const double unit = 8;          // PRD spacing.unit
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 20, xxl = 24, xxxl = 32, huge = 40;
  static const double page = 20;         // horizontal page padding
  static const double cardGap = 12, cardPad = 20, sectionGap = 24;
}
class AppRadius {
  static const double md = 12;           // PRD radius.md: map bubbles, small tags
  static const double control = 20;      // inputs, small cards
  static const double card = 28;         // cards, contour card
  static const double sheet = 32;        // top corners of sheets
  static const double pill = 999;        // buttons, chips, nav, glass bar
}
class AppSize {
  static const double touchMin = 48, touchDriver = 56;
  static const double buttonUser = 56, buttonDriver = 64;     // pill buttons
  static const double bigAction = 72;                          // driver "Mark Ward Done"
  static const double iconButton = 48, iconButtonDriver = 56;
  static const double navHeight = 72, navItem = 56, navHeightDriver = 80, navItemDriver = 64;
  static const double glassBarHeight = 64, glassBarInset = 16;
  static const double icon = 24, iconSmall = 20;
  static const double vanMarker = 44, pinWidth = 40, pinHeight = 52, markerHit = 48;
  static const double thumb = 72;                              // complaint thumbnail
}
```

Elevation (use `BoxShadow`, never Material elevation tint):

| Token | Value | Use |
|---|---|---|
| `elev0` | none | cards on the page (light), all cards in dark (use `surface` vs `background` step) |
| `elev1` | blur 16, y 4, black 6% (dark: 40%) | cards that sit on a map or on the green flow background |
| `elev2` | blur 24, y 8, black 12% (dark: 55%) | nav pill, glass bar, FAB-like buttons |
| `elev3` | blur 32, y 12, black 16% (dark: 60%) | bottom sheets, dialogs |
| `glass` | fill `surface` at 82% opacity + `BackdropFilter` blur sigma 16 | glass top bar only. Opacity MUST NOT go below 80% (text legibility over the map) |

Z-order (low to high): map, map markers, sheet, glass bar, nav pill, snackbar, dialog.

### 2.4 Theme builder: `lib/core/theme/app_theme.dart`

```dart
ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.light ? AppColors.light : AppColors.dark;
  final scheme = ColorScheme(
    brightness: b, primary: c.primary, onPrimary: c.onPrimary,
    secondary: c.brand, onSecondary: c.onBrand, tertiary: c.accent, onTertiary: c.onAccent,
    error: c.error, onError: c.background, surface: c.surface, onSurface: c.textPrimary,
    surfaceContainerHighest: c.surfaceMuted, outline: c.borderStrong, outlineVariant: c.border,
  );
  return ThemeData(
    useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: c.background,
    extensions: [c], textTheme: appTextTheme(c),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(AppSize.buttonUser), shape: const StadiumBorder(),
      backgroundColor: c.primary, foregroundColor: c.onPrimary)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: c.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: c.borderStrong, width: 1.5))),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)))),
    dialogTheme: DialogThemeData(backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card))),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: c.primary,
      contentTextStyle: TextStyle(color: c.onPrimary, fontSize: 16),
      shape: const StadiumBorder()),
  );
}
```

If a class name differs in your Flutter version (for example `DialogThemeData` vs `DialogTheme`), keep the values and adapt the class name. Widgets read colors only via `context.colors`, never `Theme.of(context).colorScheme` directly for brand or status colors.

### 2.5 Breakpoints (logical dp width)

| Class | Width | Behaviour |
|---|---|---|
| `compact` | < 360 | page padding 16, hero number 48, nav labels hidden |
| `regular` | 360-599 | default; all specs in this file |
| `large` | >= 600 | content max width 520, centered; map and sheet unchanged |

### 2.6 Motion tokens

| Token | Value |
|---|---|
| `dur.fast` | 120 ms |
| `dur.base` | 200 ms |
| `dur.slow` | 320 ms |
| `dur.ambient` | 2400 ms (mascot bob only) |
| `curve.standard` | `Curves.easeOutCubic` |
| `curve.exit` | `Curves.easeInCubic` |

### 2.7 Dark-mode rules

| Rule | Detail |
|---|---|
| Both themes define the same fields | `AppColors.light` and `AppColors.dark` have identical field sets |
| Surfaces step | page `#0E1612` < card `#16221B` < inset `#1E2D24` (no shadows needed for cards) |
| Brand flips | text/fill green becomes `#6DB36F` family; text on it is ink |
| Primary flips | primary pill is near-white with dark label |
| Map | tinted dark (D-12); markers keep the same fills |
| Illustrations | Binny SVGs are used unchanged in both themes (mid-green body contrasts with both backgrounds) |
| Contour card | identical in both themes: fill `brandMid`, lines `#1B7A3F` at 35% opacity, all text ink `#111A14` (7.05:1). Never use `textPrimary` on it (it turns white in dark) |

---

## 3. LAYOUT SYSTEM

### 3.1 Grid and safe areas

- Page horizontal padding `AppSpace.page` (20 dp; 16 on `compact`). Content respects `SafeArea`. Floating bars sit `AppSpace.lg` (16 dp) inside the safe area.
- Vertical rhythm: card gap 12, section gap 24, card padding 20. Everything snaps to the 4 dp grid.
- Single column only. Two-up tiles (stat tiles) use 2 equal columns with 12 dp gap.

### 3.2 Shells (choose exactly one per screen)

| ID | Name | Structure | Used by |
|---|---|---|---|
| M1 | Map shell | full-bleed map; glass top bar (top); draggable sheet; pill nav (bottom) | U1 Home, D2 Live Route |
| M2 | Card-list shell | page background; large `display` title; stacked cards; pill nav (bottom) | U3 My Complaints, U6 Settings, D3 Notices, D4 Pending Reports |
| M3 | Flow shell | full-screen task; round close/back button top-left; one black pill CTA pinned bottom; no nav | U2 Report a Problem, U5 Rate, D1 Shift Start, D5 End Shift, first-run setup |
| M4 | Detail sheet shell | tinted (green) header area with art or map; white rounded sheet (radius 32) holding content; back button top-left | U4 Complaint Detail |
| M5 | Splash/onboarding shell | `brandMid` background with organic leaf blob, Binny, title, black pill CTA | Splash, first-run welcome |

### 3.3 Dimensions

| Element | Spec |
|---|---|
| Glass top bar | height 64, inset 16 from safe top and 16 from sides, radius pill, `glass` fill, `elev2`. Contents: round 48 icon slot (ward/place icon in `brandSoft` circle) + two-line text (ward name `titleSmall`, subtitle `bodySmall` muted) + round 48 icon button(s) at the right (language toggle, then search/refresh). D2 override (changed 2026-10-28: notices bell removed from the glass bar — the pill nav is the notices entry): icon slot = route icon, subtitle = TrackingBadge, ONE settings icon button on the right |
| Pill nav (user) | height 72, auto width (3 items), centered, bottom inset 16 + safe area, radius pill, `surface`, `elev2`, inner padding 8. Item = 56 circle. Active item = `primary` circle with `onPrimary` icon. Inactive = transparent with `textMuted` icon. Label NOT shown (icons + `Semantics` label); on `regular` and above show no labels |
| Pill nav (driver) | height 80, item circle 64, same style |
| Bottom sheet on map | radius 32 top, `surface`, `elev3`, grab handle 40 x 4 `borderStrong`. Snap points (fraction of screen height): collapsed 0.22, default 0.36, expanded 0.88. Sheet bottom padding includes the nav height + 16 so content is never covered by the nav |
| Page title block (M2) | top padding 24 below safe area; `display` title; optional `bodySmall` muted subtitle 8 below |
| CTA bar (M3) | pinned at bottom: padding 20 horizontal, 16 bottom + safe area; button height 56 (driver 64); a 16 dp gradient fade of `background` above it when content scrolls under |
| Contour card | min height 160, radius 28, padding 20; content left, optional round 48 arrow button top-right |
| Stat tile | 2-up, min height 112, radius 28, padding 16 |
| Complaint card | radius 28, padding 16, thumbnail 72 x 72 radius 20 at left, text column, status chip bottom-left of the text column |

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

- Text left aligned (right aligned only in a right-to-left locale; none are used now). Big numbers left aligned inside their card.
- One primary action per screen, centered full width at the bottom (M3) or as a prominent pill button in the sheet (M1).
- Hierarchy order on any screen: (1) the one signature/status element, (2) the primary action, (3) supporting cards, (4) utilities.
- Header actions are round icon buttons (48), never text links.

---

## 4. COMPONENT LIBRARY (Flutter widget specs)

### 4.0 Global state model

| State | Visual rule |
|---|---|
| default | as specified |
| pressed | scale 0.98 for 120 ms + overlay `textPrimary` at 8% |
| focused (keyboard/TalkBack) | 3 dp outline `brand` (dark: `brand`) offset 2, never removed |
| disabled | 40% opacity, no shadow, `Semantics(enabled: false)` and a reason text if the cause is non-obvious |
| loading | label replaced by a 20 dp circular progress (same width, no layout jump); control not tappable |
| error | `error` outline 1.5 + helper text with an icon, never color alone |
| selected | per component (chip = accent fill; nav = ink circle) |

### 4.1 AppButton (`lib/core/widgets/app_button.dart`)

| Variant | Fill | Label | Size | Use |
|---|---|---|---|---|
| `primary` | `primary` | `onPrimary`, `button` | full width, height 56 (driver 64), pill | the ONE main action `[from-image:2]` |
| `secondary` | transparent, 1.5 `borderStrong` outline | `textPrimary` | same | alternative action |
| `tonal` | `brandSoft` | `brand` text | same | safe, low-emphasis action |
| `text` | none | `brand` | height 48, min width 48 | inline link-like action |
| `accent` | `accent` | `onAccent` (ink) | same | rare; "needs attention" call out (for example Van Didn't Arrive) |

Trailing icon 24 dp allowed on `primary` (camera icon on "Take photo" `[from-image:2]`). No leading icons on primary. Disabled and loading follow 4.0.

### 4.2 AppIconButton

48 dp circle (driver 56). Fill `surface` (or glass when on the map), icon 24 outline `textPrimary`, `elev2` only when floating on a map. Header buttons in M2/M3 use `surfaceMuted` fill, no shadow. Always has `Semantics(label:)` and a tooltip text.

### 4.3 AppChip (category chips, filters)

Height 48 (touch), radius pill, padding 16 horizontal, icon 20 + label (`label`). Unselected: `surface` fill + 1.5 `borderStrong`. Selected: `accent` fill, `onAccent` text, 1.5 `onAccent` outline (not color alone: also shows a leading check icon 20). Chips wrap with 8 dp gaps; a row never scrolls horizontally when <= 5 chips `[from-image:2]`.

### 4.4 AppTextField (note, PIN)

Pill-like: radius 20, height 56 (multi-line min 96), fill `surface`, 1.5 `borderStrong` outline, label above the field (8 dp gap, `label`), hint `textMuted`. Focus: outline `brand` 2.5. Error: outline `error` + helper text with `error` icon. PIN field (driver): 4 separate 56 x 64 boxes, numeric keypad, obscured.

### 4.5 PillNav

See 3.3. Items: user = Map, My Complaints, Settings; driver = Route, Notices, Reports. Badge: 20 dp circle `accentStrong` fill + white 14 sp number (white on `accentStrong` 5.38:1), top-right of the item, only for unread counts.

### 4.6 GlassBar (top bar on M1)

See 3.3. If `BackdropFilter` is unavailable or the device is low-end, use `surface` at 100%.

### 4.7 StatusChip

Height 32, radius pill, padding 12 horizontal, `soft` fill, `text` color label (`label`), leading 20 dp icon in `text` color:

| Status | Label key | Icon |
|---|---|---|
| `received` | `status.received` | `inbox` |
| `assigned` | `status.assigned` | `assignment_ind` |
| `resolved` | `status.resolved` | `check_circle` |
| `escalated` | `status.escalated` | `priority_high` |
| local only (not sent yet) | `status.queued` | `cloud_off`, colors `surfaceMuted` fill + `textMuted` text |

Always icon + label + color. A dot alone is never a status.

### 4.8 Cards

| Card | Spec |
|---|---|
| Basic card | `surface`, radius 28, padding 20, `elev0` (page) or `elev1` (on map/green) |
| Stat tile | `surface`, radius 28, padding 16; label `titleSmall` top-left; 48 round arrow button top-right (`surfaceMuted`); value `headline` bottom-left with unit `bodySmall` muted; faint 3 dp dot texture bottom-right at 12% `textMuted` `[from-image:1]` |
| Complaint card | see 3.3; whole card tappable (min 96 tall); trailing chevron NOT used; shows ticket ID (`bodySmall` muted), category title (`titleSmall`), time (`bodySmall` muted), status chip |
| Info card | `brandSoft` fill, no shadow, leading icon 24 `brand`, `body` text |
| Notice card (driver) | `surface`, radius 28, unread = 4 dp left bar `accent` + bold title |

### 4.9 ContourCard (SIGNATURE, MUST be reused, rule CL-12)

Widget `ContourCard({child, seed, onArrow})`. Fill `brandMid`, radius 28, `ClipRRect`, min height 160, padding 20, all text ink. `CustomPaint` behind the child draws the contour lines (copy verbatim):

```dart
class ContourPainter extends CustomPainter {
  ContourPainter({required this.seed, this.lines = 9});
  final int seed; final int lines;
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final cx = size.width * (0.35 + rnd.nextDouble() * 0.3);
    final cy = size.height * (0.35 + rnd.nextDouble() * 0.3);
    final p1 = rnd.nextDouble() * math.pi * 2, p2 = rnd.nextDouble() * math.pi * 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..color = const Color(0xFF1B7A3F).withOpacity(0.35);
    final maxR = size.longestSide * 0.9;
    for (var i = 1; i <= lines; i++) {
      final r = maxR * i / lines;
      final path = Path();
      for (var a = 0; a <= 360; a += 6) {
        final t = a * math.pi / 180;
        final rr = r * (1 + 0.10 * math.sin(2 * t + p1) + 0.06 * math.sin(3 * t + p2));
        final x = cx + rr * math.cos(t), y = cy + rr * math.sin(t) * 0.75;
        a == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }
  @override
  bool shouldRepaint(ContourPainter o) => o.seed != seed || o.lines != lines;
}
```

Seed = stable per entity (hash of `wardId` or `complaintId`) so the pattern never changes between visits. Content layout: label (`bodySmall`) top-left, `heroNumber` + unit (`titleSmall`), one supporting line (`body`) right or below. One ContourCard per screen maximum, at the top of the content. Uses: U1 sheet (ETA), U4 header (ticket status), D2 sheet (route progress), D5 (shift summary).

### 4.10 Map layer components

| Component | Spec |
|---|---|
| Map tiles | `flutter_map` OSM tiles, attribution visible (`attribution` style) bottom-left above the nav. Tint (D-12, `[inferred]`): light = multiply `brandSoft` at 35%; dark = invert matrix then multiply dark `surface` at 55% |
| VanMarker | 44 dp circle, `brand` fill, 3 dp white ring, truck icon 24 white (light) / ink (dark, on `brandMid`); hit area 48; moving = soft pulse ring 2400 ms (static when reduced motion); stale (older than STALE_LOCATION_SEC) = `surfaceMuted` fill, `textMuted` icon, label "Last seen X min ago" in the EtaBubble |
| EtaBubble | above the marker; `surface`, radius 12, padding 8 x 12, `elev2`; text `label`: "12 min" or "Last seen 3 min ago"; pointer 8 dp |
| ComplaintPin | teardrop 40 x 52, `status.fill`, white 24 circle inside with status icon 16 in `status.text` color |
| User location | 16 dp `accent` dot with 3 dp white ring + 40 dp `accent` 20% halo |
| Ward area | dashed 2 dp `brand` outline, 8% `brand` fill (optional) |
| Recenter button | AppIconButton 48 on the map, bottom-right above the sheet |

### 4.11 BottomSheet (draggable)

See 3.3. Content order inside the sheet: ContourCard -> primary actions -> secondary cards. Never nest scrolling inside the collapsed sheet.

### 4.12 CameraViewfinder (U2)

Full-screen preview; four 40 dp corner brackets, 4 dp white stroke, radius 12, inset 40 `[from-image:2]`; top: round close button (left), flash toggle (right) both 48 on glass; below the preview: category chips (4.3) in a surface strip; bottom: black pill "Take photo" button with camera icon trailing `[from-image:2]`. After capture: preview with "Retake" (`secondary`) and "Use photo" (`primary`), plus a one-line privacy notice (`bodySmall`). NEVER a gallery button.

### 4.13 StatusTimeline (U4)

Vertical list; node = 24 dp circle (`status.fill` for reached, `border` for future) with the status icon inside in white/`textMuted`; 2 dp connector `border`; each row: label (`titleSmall`), time (`bodySmall` muted). Reached rows are fully opaque; future rows 60% opacity.

### 4.14 RatingStars (U5)

5 stars, each a 48 dp touch target, outline when empty, filled `accent` when selected (plus the number "3 of 5" as text beside).

### 4.15 Banners and feedback

| Component | Spec |
|---|---|
| OfflineBanner | pill under the glass bar: `surfaceMuted`, `cloud_off` icon + "You are offline. Reports will be sent later." |
| StaleBanner | same style, `schedule` icon, "Van location may be old" |
| SnackBar | floating, pill, `primary` fill, `onPrimary` text, 4 s, one optional text action |
| ConfirmDialog | radius 28, `elev3`, title `title`, body `body`, buttons stacked full width (primary on top, `secondary` below) |
| InlineError | `error` icon 20 + `bodySmall` `error` text under the field |

### 4.16 Empty / loading components

| Component | Spec |
|---|---|
| EmptyState | centered column: Binny (160) + `title` + `body` muted + optional `primary`/`tonal` button. Mascot rules in 4.20 |
| Skeleton | `surfaceMuted` rounded blocks matching the real layout, shimmer 1200 ms (static when reduced motion) |
| Spinner | 20 dp inside buttons; 32 dp centered for full-screen loads |

### 4.17 Driver-specific components

| Component | Spec |
|---|---|
| BigActionButton | height 72, full width, pill, `primary`, label uses `button` (16 sp); optional leading icon 28; one per screen: "Mark Ward Done"; label swaps to "End Shift" once every ward is done (opens D5) (changed 2026-10-28: End Shift moved here from the D2 "more" menu) |
| WardRow | height 72, `surface` card radius 28; leading 48 circle (`primary` + number if next, `brand` + check if done, `surfaceMuted` + number if pending); title `titleSmall`; done time `bodySmall` muted. Done rows have a check icon plus the word "Done" |
| PinPad | 4 boxes + system numeric keypad; wrong PIN shows InlineError and a 120 ms flash of the outline in `error` (no shake) |
| TrackingBadge | pill in the glass bar: 8 dp `brand` dot + "Tracking active" text (text always present); label ellipsizes (`Flexible`) and never overflows the glass bar (changed 2026-10-28) |

### 4.18 Language toggle

48 dp pill-shaped segmented control in the glass bar or Settings: two segments "ગુ" and "EN", selected segment = `primary` fill with `onPrimary` text. Visible on U1 (glass bar), first-run, Settings.

### 4.19 Permission prompt screen

M3 shell. Binny `wait` pose is NOT allowed here if the permission was denied (rule 4.20); use a 96 dp `brandSoft` circle with the relevant icon (location, camera, notifications). Title `headline`, `body` explanation in both languages' strings, `primary` "Allow", `text` "Not now". Denied state: `info card` with the reason and an "Open settings" `tonal` button.

### 4.20 Binny (mascot) (`lib/core/widgets/binny.dart`)

| Pose | Asset | Use (ONLY these) |
|---|---|---|
| `wave` | `assets/mascot/binny-wave.svg` | Splash, first-run welcome |
| `wait` | `assets/mascot/binny-wait.svg` | "No van on route right now", empty My Complaints, empty Pending Reports, empty Notices |
| `celebrate` | `assets/mascot/binny-celebrate.svg` | after a complaint is sent, after a ward/route is done, after Resolved |
| `sleep` | `assets/mascot/binny-sleep.svg` | offline with nothing to show, shift ended |

Sizes: 96 (inline in cards), 160 (empty states), 220 (splash). Gentle bob: translateY +-6 dp over `dur.ambient`, disabled when reduced motion. Informational use gets `semanticsLabel` text; decorative use is wrapped in `ExcludeSemantics`.

NEVER show Binny on: errors, failed uploads, permission denied, destructive confirmations, escalated complaints, the driver's live map. NEVER animate it faster than `dur.ambient`. NEVER recolor or redraw it. One Binny per screen.

```dart
enum BinnyPose { wave, wait, celebrate, sleep }
class BinnyView extends StatefulWidget {
  const BinnyView({super.key, required this.pose, this.size = 160, this.label});
  final BinnyPose pose; final double size; final String? label;
  @override State<BinnyView> createState() => _BinnyViewState();
}
class _BinnyViewState extends State<BinnyView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  @override void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.of(context).disableAnimations ? _c.stop() : _c.repeat(reverse: true);
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final img = SvgPicture.asset('assets/mascot/binny-${widget.pose.name}.svg',
        height: widget.size, semanticsLabel: widget.label);
    return AnimatedBuilder(animation: _c, builder: (_, child) =>
        Transform.translate(offset: Offset(0, -6 * Curves.easeInOut.transform(_c.value)), child: child),
        child: widget.label == null ? ExcludeSemantics(child: img) : img);
  }
}
```

---

## 5. CONSISTENCY LAW (testable; cite by ID)

| ID | Rule |
|---|---|
| CL-01 | Colors ONLY via `context.colors`. No raw `Color(0x...)` outside `app_colors.dart` and `ContourPainter` |
| CL-02 | Spacing ONLY via `AppSpace`. No numeric margin/padding literals except `0` |
| CL-03 | Radius ONLY via `AppRadius` |
| CL-04 | Text ONLY via `context.text` styles from Section 2.2. No inline `fontSize` or `fontWeight` |
| CL-05 | No informational text below 14 sp. 12 sp is allowed only for map attribution and legal lines |
| CL-06 | Every tappable is at least 48 x 48 dp (driver app: 56 x 56) |
| CL-07 | Exactly ONE `primary` (filled ink) button per screen |
| CL-08 | The primary CTA is a full-width pill: pinned at the bottom in M3, inside the sheet in M1 |
| CL-09 | Status is ALWAYS color + icon + label, rendered only by `StatusChip` (or `ComplaintPin` on maps) |
| CL-10 | `error` color is for validation and failure messages only. Escalated complaints use `statusEscalated` |
| CL-11 | Orange: fills carry ink text; orange text or orange behind white text MUST use `accentStrong`. NEVER white on `accent` |
| CL-12 | The ContourCard is the ONLY top status element for: ETA (U1), ticket status (U4), route progress (D2), shift summary (D5). NEVER replace it with a generic card, chart or banner |
| CL-13 | Maximum one ContourCard per screen, always the first content element |
| CL-14 | `brandMid` and `brandLeaf` NEVER carry text other than ink |
| CL-15 | Binny appears only where Section 4.20 allows, one per screen, never on errors or destructive screens |
| CL-16 | Cards: radius 28, no border. Inputs: radius 20 with 1.5 dp `borderStrong` outline. Chips, buttons, nav: pill |
| CL-17 | Shadows ONLY from `elev1` to `elev3`. Set `surfaceTintColor: Colors.transparent` on Material surfaces |
| CL-18 | Glass bar opacity >= 80%; text on it uses `textPrimary` |
| CL-19 | Icons: Material Symbols Outlined, 24 dp (20 inside chips), weight 300. Filled glyphs only for status icons and the selected van marker |
| CL-20 | No widget branches on `Brightness` for color. Both themes use the same widget code |
| CL-21 | All strings come from localization (`gu`, `en`). Layouts MUST survive strings 150% longer than English |
| CL-22 | The language toggle is reachable in at most 1 tap from U1 and the first-run screen, and always present in Settings |
| CL-23 | The report flow has NO gallery, file picker or "choose from library" control anywhere |
| CL-24 | Every screen implements loading, empty, error and offline states (Section 7) |
| CL-25 | Every tappable has a `Semantics` label (or visible text) in the active language |
| CL-26 | No horizontal scrolling of page content (the map is the only pan surface) |
| CL-27 | M1 and M2 show the pill nav; M3, M4, M5 never do. M3 and M4 show a back/close button top-left |
| CL-28 | Never show raw exception text, stack traces or error codes to the user. Use the copy patterns in Section 7.2 |
| CL-29 | Every tappable defines the pressed state from 4.0 |
| CL-30 | Lists are separated by 12 dp gaps, never divider lines |
| CL-31 | One font family (Noto Sans + Gujarati fallback), weights 300 to 600 only |
| CL-32 | Numbers in `heroNumber` use tabular figures |
| CL-33 | Times under 24 h old are relative ("5 min ago"); older use a locale date from `intl` |
| CL-34 | Driver app uses driver sizes everywhere (56/64/72/80); never mix user and driver sizes in one screen |
| CL-35 | Map camera padding accounts for the sheet and nav so the van marker is never hidden behind them |
| CL-36 | The photo preview (U2) always shows the one-line privacy notice |

---

## 6. DECISION MATRICES

### DM-01 Content -> component

| Content | Component |
|---|---|
| One key number or status that matters most | ContourCard |
| 2 supporting metrics | 2 stat tiles |
| A report or ticket in a list | ComplaintCard |
| Progress through steps | StatusTimeline |
| Choose 1 of 2-5 options | AppChip row |
| Choose 1 of 6+ options (ward list) | bottom sheet list with search |
| On/off setting | switch row inside a basic card |
| Short free text | AppTextField |
| Quality score | RatingStars |
| Message from admin | Notice card |
| Instructional or reassurance text | Info card |

### DM-02 Field count -> form layout

| Fields | Layout |
|---|---|
| 1 | inline inside the sheet or M3 body |
| 2-4 | M3 shell, stacked, 16 dp gaps |
| 5+ | not expected; split into M3 steps, never one long scroll |

### DM-03 Data volume -> presentation (lists)

| Items | Presentation |
|---|---|
| 0 | EmptyState with Binny `wait` |
| 1-10 | plain list |
| 11-50 | list with "Show more" (page size 10) |
| 50+ | month group headers + "Show more" |

### DM-04 Severity -> pattern

| Situation | Pattern |
|---|---|
| Neutral info | Info card |
| Success (sent, done) | celebrate screen (Binny `celebrate`) or SnackBar for minor actions |
| Warning (stale, offline) | banner under the glass bar |
| Recoverable error (upload failed) | InlineError + "Try again" `tonal` button; queue and auto-retry |
| Blocking error (cannot load the app data) | full-screen error with `title`, `body`, `primary` "Try again". No mascot |
| Destructive or irreversible | ConfirmDialog (stacked buttons) |

### DM-05 Width -> layout: see Section 11.

### DM-06 State -> UI

| State | UI |
|---|---|
| Loading | Skeleton matching the final layout |
| Empty | EmptyState (Binny `wait` + one sentence + optional action) |
| Error | DM-04 |
| Offline | OfflineBanner; queued items show the `queued` chip |
| Stale data | StaleBanner + muted marker (4.10) |
| Success | DM-04 |

### DM-07 Intent -> CTA hierarchy

| Intent | Variant |
|---|---|
| The one main task on the screen | `primary` |
| A second valid path | `secondary` |
| Safe, low-emphasis (Retake, Open settings) | `tonal` |
| Needs attention (Van Didn't Arrive) | `accent` |
| Skip / later / inline link | `text` |

---

## 7. STATES AND FEEDBACK

### 7.1 Validation timing

| Context | When | How |
|---|---|---|
| Report category | on Submit | inline error under the chips: "Choose what you are reporting" |
| Note field | never required | max 200 chars, counter shown at 150+ |
| Driver PIN | on the 4th digit | flash outline `error` 120 ms + InlineError |
| Location unavailable (camera) | at the shutter | block with Info card + "Turn on location" `tonal` button |
| Daily limit reached | on Submit | Info card: "You have reached today's limit. Try again tomorrow." |

### 7.2 Copy patterns (all strings in `gu` and `en`)

- Sentence case. Max 12 words per message. No jargon, no codes, no exclamation marks except success.
- Pattern: what happened + what to do. Example: "Could not send. We will try again when you are online."
- Buttons: verb + noun, max 3 words ("Take photo", "Use photo", "Start shift").
- String keys: `area.screen.element` (example `report.camera.takePhoto`).
- Success titles: "Sent", "Done", "Thank you" only.

### 7.3 Optimistic updates

| Action | Behaviour |
|---|---|
| Submit complaint | appears at the top of My Complaints immediately with the `queued` chip until the upload finishes, then switches to `received` |
| Mark ward done (driver) | the WardRow turns to done immediately; on write failure it reverts and shows a SnackBar with "Try again" |
| Rate service | stars fill immediately; thank-you SnackBar |

### 7.4 Offline

Show OfflineBanner. Complaints queue locally (photo + data) and send automatically on reconnect, with the `queued` chip and a count in My Complaints. Map shows the last known van position with the stale rule (4.10). Never block the camera because of network loss.

### 7.5 Unsaved changes

If a photo is taken or a note typed and the user presses close/back in M3: ConfirmDialog "Discard this report?" with `primary` "Keep editing" and `secondary` "Discard".

### 7.6 Permissions

Ask only when needed, with the rationale screen (4.19) first. Denied once: Info card on the feature screen + "Open settings" `tonal` button. The app MUST remain usable without notifications. Location is required for Report and for ward detection; fall back to the manual ward picker.

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
| Binny idle bob | translateY +-6 dp | 2400 ms | ease in-out |
| Binny pose appearing (success) | scale 0.9 -> 1 + fade | 320 ms | `standard` |
| SnackBar | slide up | 200 ms | `standard` |
| Skeleton shimmer | gradient sweep | 1200 ms | linear |

Forbidden: bounce or elastic curves, parallax, confetti, shake, auto-playing loops other than the table above, any non-ambient animation longer than 400 ms, spinners larger than 32 dp.

Reduced motion (`MediaQuery.disableAnimations`): all durations become 0 except a 120 ms fade; stop the pulse ring, Binny bob and shimmer (show static versions).

---

## 9. PAGE TEMPLATES

Legend: `[...]` button, `(...)` icon button, `<...>` component. Screen IDs match PRD-1 and PRD-2.

### 9.1 Splash and welcome (M5) `[from-image:2]`

```
+--------------------------------+
|  brandMid background + blob    |
|                                |
|       <Binny wave, 220>        |
|                                |
|  Safai Sathi        (display)  |
|  See your van. Report problems |
|  in seconds.        (body,ink) |
|                                |
|  [ Get Started            -> ] |  primary, bottom
+--------------------------------+
```

### 9.2 First-run setup (M3, 3 steps with a 3-dot indicator) `[inferred]`

```
+--------------------------------+
|  ( )3-dot step indicator       |
|  Choose language   (headline)  |
|  [ ગુજરાતી ]  [ English ]      |  large chips
|                                |
|  Step 2: <permission prompt>   |  location rationale (4.19)
|  Step 3: Where do you live?    |  [Use my location] tonal
|          <ward picker field>   |  or pick from list
|  [ Continue ]                  |  primary
+--------------------------------+
```

### 9.3 U1 Home (M1) `[from-image:1]` layout

```
+--------------------------------+
| <GlassBar> (o) Ward name  [ગુ|EN] (refresh) |
| <OfflineBanner / StaleBanner>  |
|                                |
|          MAP                   |
|     <VanMarker> <EtaBubble>    |
|     <UserLocation>             |
|                          (⌖)  |
|==== sheet, snap 0.36 ==========|
|  ----                          |
|  <ContourCard>                 |
|   Van arrives in               |
|   12 min   (unit)   Van GJ-xx  |
|  [ Report a Problem      (cam) ]|  primary
|  [ Van didn't arrive today ]   |  accent, only after scheduled start
|          <PillNav>             |
+--------------------------------+
```
No van on shift: ContourCard is replaced by the EmptyState variant inside the sheet (Binny `wait`, "No van on route right now", scheduled time). The ContourCard rule still applies when a van exists.

### 9.4 U2 Report a Problem (M3 camera) `[from-image:2]`

```
+--------------------------------+
| (x)                      (flash)|
|  +--------------------------+  |
|  |  corner brackets         |  |
|  |      camera preview      |  |
|  +--------------------------+  |
|  [garbage][gutter][missed][other] chips
|  [ Take photo           (cam) ] |  primary
+--------------------------------+
After capture: preview + note field + privacy line
  [ Retake ] secondary   [ Use photo ] primary -> Submit
Success: <Binny celebrate> "Sent"  Ticket PMH-20261024-0412  [ View my complaints ] primary
```

### 9.5 U3 My Complaints (M2)

```
+--------------------------------+
|  My Complaints       (display) |
|  <ComplaintCard> thumb | PMH-.. |
|                        Garbage dump
|                        2 h ago
|                        <StatusChip>
|  <ComplaintCard> ...           |
|          <PillNav>             |
+--------------------------------+
Empty: <Binny wait> "No reports yet" + [ Report a Problem ] tonal
```

### 9.6 U4 Complaint Detail (M4)

```
+--------------------------------+
| (<)   photo header (green tint)|
|==== white sheet radius 32 =====|
| <ContourCard> Ticket PMH-..    |
|   Status text   (heroNumber n/a: use headline)
| <StatusTimeline>               |
| Resolved photo (if any)        |
| Location mini map              |
+--------------------------------+
```

### 9.7 U6 Settings (M2)

```
+--------------------------------+
|  Settings            (display) |
|  <Card> Language   [ગુ|EN]     |
|  <Card> My ward    Name  (>)   |
|  <Card> Theme  [Light|Dark|System] segmented
|  <Card> Privacy & about        |
|          <PillNav>             |
+--------------------------------+
```

### 9.8 D1 Shift Start (M3) `[inferred]`

```
+--------------------------------+
|  Start shift         (headline)|
|  Van      <picker field>       |
|  Route    Godhra East (read-only chip)
|  PIN      [ ][ ][ ][ ]         |
|  [ Start Shift ]               |  primary, 64 high
+--------------------------------+
```

### 9.9 D2 Live Route (M1, driver sizes) `[inferred]`

```
+--------------------------------+
| <GlassBar> route + TrackingBadge (settings) |
| <OfflineBanner / tracking / mock-location> |
|          MAP: van, wards       |
|==== sheet snap 0.36 ===========|
|  <ContourCard> 4 of 9 wards    |
|  [ Mark Ward Done: Ward 5  ]   |  <BigActionButton> 72 high; becomes [ End Shift ] once every ward is done
|  <WardRow> done ...            |
|  <WardRow> next ...            |
|       <PillNav driver>         |
+--------------------------------+
```
Changed 2026-10-28: notices bell removed from glass bar — PillNav is the notices entry; end-of-trip banner removed — End Shift is the sheet's primary once all wards are done; TrackingBadge ellipsizes. Banners remaining in the slot under the glass bar: offline note, tracking-state (GPS off / permission denied, with Retry), mock-location warning. There is no other end-of-trip card, summary seam or End Shift button on this screen.
Landscape: map left (60%), panel right (40%, max 420) holding ContourCard + BigActionButton + ward list; nav pill stays bottom-left.

### 9.10 Remaining screens (compact)

| Screen | Shell | Content order |
|---|---|---|
| U5 Rate Today's Service | M3 | question `headline`; `<RatingStars>`; optional note; `primary` "Submit" |
| D3 Notices | M2 | `display` title; Notice cards (unread first); empty = Binny `wait` |
| D4 Pending Reports | M2 | title; complaint cards with two `tonal` actions "Will revisit" / "Done"; empty = Binny `wait` |
| D5 End Shift | M3 | ContourCard (wards done, duration); `primary` "End Shift"; after: Binny `sleep` "Shift ended" |
| Permission prompt | M3 | per 4.19 |
| Blocking error | M3 | icon in `brandSoft` circle, `title`, `body`, `primary` "Try again". No mascot |
| Offline (nothing cached) | M3 | Binny `sleep`, "You are offline", `tonal` "Try again" |

---

## 10. USER FLOWS

| ID | Flow | Screens in order | Persists | Consistency anchors |
|---|---|---|---|---|
| F1 | First launch | Splash -> language -> location permission -> ward confirm -> U1 | language, `wardId`, theme | same M3 shell for all 3 steps; ONE primary per step |
| F2 | Report a problem | U1 -> U2 camera -> preview (+note) -> Submit -> success -> U3 | queued complaint until uploaded | CTA stays at the bottom in the same position on every step; no gallery |
| F3 | Van didn't arrive | U1 -> tap accent button -> ConfirmDialog -> SnackBar "Reported" (Binny not used) | one report per ward per day | uses the same ComplaintCard in U3 afterward |
| F4 | Driver shift | D1 -> D2 (mark wards) -> D5 -> D1 | session, shift, trail buffer | big sizes (CL-34); tracking badge always visible on D2 |
| F5 | Notification tap | push -> U1 (arrival alert) or D3 (notice) | nothing | opens the target screen with the pill nav visible |
| F6 | Check a ticket | U3 -> U4 -> back | nothing | status shown only by StatusChip / ContourCard |

Consistency must not break at: language switch (instant, no restart, same layout), theme switch (no rebuild flash > 120 ms), and the offline queue (the same chip and card styles).

---

## 11. RESPONSIVE MATRIX

| Component / page | compact (<360) | regular (360-599) | large (>=600) |
|---|---|---|---|
| Page padding | 16 | 20 | 20, content max width 520 centered |
| Glass bar | hide the subtitle line | full | full |
| Pill nav | icons only | icons only | icons only |
| ContourCard hero number | 48 | 56 | 56 |
| Stat tiles | 1 column | 2 columns | 2 columns |
| Sheet snaps | 0.26 / 0.40 / 0.90 | 0.22 / 0.36 / 0.88 | 0.22 / 0.36 / 0.88 |
| Chips row | wraps to 2 lines | wraps | wraps |
| CTA | full width | full width | width 520 centered |
| Driver landscape | n/a | map 60% + panel 40% | map 60% + panel 40% |

Text scale: layouts MUST remain usable at system text scale 1.3 (and not break at 2.0: cards grow vertically, nothing is clipped, buttons wrap to two lines).

---

## 12. ACCESSIBILITY

| Area | Rule |
|---|---|
| Contrast | WCAG AA: text >= 4.5:1, large text and UI shapes >= 3:1 (Appendix D). Both themes |
| Targets | 48 dp (driver 56) minimum with 8 dp spacing between adjacent targets |
| Screen reader | TalkBack labels in the active language on every control; map has a text alternative: the sheet always states "Van is 12 min away" in text; markers expose `Semantics` |
| Focus | visible 3 dp focus ring on every interactive element; logical order top to bottom |
| Color independence | status = color + icon + label; selected chip = fill + check icon |
| Text scaling | support 1.0 to 2.0 without clipping |
| Motion | respects reduced motion (Section 8) |
| Camera | shutter button has a label; capture confirmation is announced ("Photo taken") |
| Language | `Localizations` locale set to `gu` or `en`; TalkBack reads Gujarati with the correct locale |
| Testing | run Flutter semantics debugger, TalkBack pass on U1, U2, D2, and the checklist (Section 14) in both themes |

---

## 13. AGENT PROTOCOL

### 13.1 Imperative rules

1. Read this whole file, then the PRD of the app you are building (PRD-1 user, PRD-2 driver), before writing code.
2. Build ONE screen at a time. For each screen: pick the shell (3.2), copy its template (Section 9), compose only components from Section 4, run Section 14.
3. Never write a color, size, radius or text style literal. Use tokens (CL-01 to CL-04).
4. If a needed element has no spec, ADD a spec to Section 4 first, then use it.
5. Implement loading, empty, error and offline states for every screen (CL-24) and both themes (CL-20).
6. Do not rename tokens, collections or fields. Data names come from the PRD shared contract.
7. Use ONLY the four Binny SVGs. Never redraw or generate mascot art.
8. When the PRD and this file disagree on behaviour, the PRD wins; on appearance, this file wins.

### 13.2 Helpers (create exactly these)

```dart
// lib/core/theme/app_text.dart
extension AppTextX on BuildContext { TextTheme get text => Theme.of(this).textTheme; }

TextTheme appTextTheme(AppColors c) {
  TextStyle s(double size, double line, FontWeight w, {List<FontFeature>? f}) => TextStyle(
      fontFamily: 'NotoSans', fontFamilyFallback: const ['NotoSansGujarati'],
      fontSize: size, height: line / size, fontWeight: w, color: c.textPrimary, fontFeatures: f);
  return TextTheme(
    displayLarge: s(56, 60, FontWeight.w400, f: const [FontFeature.tabularFigures()]), // heroNumber
    displayMedium: s(36, 44, FontWeight.w300),                                         // display
    headlineMedium: s(28, 36, FontWeight.w500),                                        // headline
    titleLarge: s(20, 30, FontWeight.w600),                                            // title
    titleMedium: s(16, 24, FontWeight.w600),                                           // titleSmall
    bodyLarge: s(16, 24, FontWeight.w400),                                             // body
    bodyMedium: s(14, 22, FontWeight.w400),                                            // bodySmall
    labelLarge: s(16, 24, FontWeight.w600),                                            // button
    labelMedium: s(14, 20, FontWeight.w600),                                           // label
    bodySmall: s(12, 16, FontWeight.w400),                                             // attribution ONLY
  );
}
```

Style name to TextTheme slot: heroNumber=displayLarge, display=displayMedium, headline=headlineMedium, title=titleLarge, titleSmall=titleMedium, body=bodyLarge, bodySmall=bodyMedium, button=labelLarge, label=labelMedium, attribution=bodySmall. Muted text = same style with `color: context.colors.textMuted`.

### 13.3 Build order

| Step | Build |
|---|---|
| 1 | `pubspec.yaml` (fonts, `assets/mascot/`, packages), `app_colors.dart`, `app_tokens.dart`, `app_text.dart`, `app_theme.dart`, localization files |
| 2 | Core widgets: `AppButton`, `AppIconButton`, `AppChip`, `AppTextField`, `StatusChip`, `PillNav`, `GlassBar`, `ContourCard`, `Binny`, `EmptyState`, banners, `Skeleton` |
| 3 | Shells M1 to M5 as reusable scaffolds |
| 4 | Splash, first-run setup, U1 Home (PRD Phase 1 location loop) and D1 + D2 (driver) |
| 5 | U2 Report + success, U3, U4 (PRD Phase 2) |
| 6 | D3, D4, D5, U5, U6 and notification handling (PRD Phases 3-4) |
| 7 | Dark-mode pass, text scale 1.3 pass, TalkBack pass, Section 14 on every screen |

### 13.4 Folder structure (matches PRD architecture rules)

```
lib/core/theme/        app_colors.dart  app_tokens.dart  app_text.dart  app_theme.dart
lib/core/widgets/      app_button.dart  app_chip.dart  status_chip.dart  contour_card.dart  binny.dart
                       pill_nav.dart  glass_bar.dart  empty_state.dart  banners.dart  skeleton.dart  shells/
lib/core/l10n/         app_en.arb  app_gu.arb
assets/mascot/         binny-wave.svg  binny-wait.svg  binny-celebrate.svg  binny-sleep.svg
assets/fonts/          NotoSans-*.ttf  NotoSansGujarati-*.ttf
```
Feature screens live in `lib/features/<feature>/ui/` (PRD 0.11) and import only from `core/widgets` and `core/theme`.

### 13.5 Anti-patterns (NEVER)

| ID | Anti-pattern |
|---|---|
| AP-01 | Raw `Color(0x...)`, `Colors.green`, `Colors.red` in feature code |
| AP-02 | Inline `TextStyle(fontSize: ...)` |
| AP-03 | Numeric padding/margin/radius literals |
| AP-04 | More than one `primary` button on a screen |
| AP-05 | Status shown as a colored dot or color only |
| AP-06 | White text on `accent` or on `brandMid` |
| AP-07 | Generic Material `Card` instead of the 28 dp card spec |
| AP-08 | Divider lines between list items |
| AP-09 | A gallery or "choose from files" button in the report flow |
| AP-10 | Binny on an error, permission-denied or destructive screen |
| AP-11 | Redrawing, recoloring or animating Binny faster than 2400 ms |
| AP-12 | Replacing the ContourCard with a plain card or a chart |
| AP-13 | Two ContourCards on one screen |
| AP-14 | Runtime font downloads (`google_fonts` network fetch) |
| AP-15 | Hardcoded English or Gujarati strings in widgets |
| AP-16 | Showing exception text or error codes to users |
| AP-17 | Touch targets below 48 dp (driver 56 dp) |
| AP-18 | Text below 14 sp (except map attribution) |
| AP-19 | Branching widget code on `Brightness` for colors |
| AP-20 | Material elevation tint (leave `surfaceTintColor` transparent) |
| AP-21 | Horizontal scrolling page content |
| AP-22 | Pill nav on M3, M4 or M5 screens |
| AP-23 | Parallax, bounce, confetti or shake animations |
| AP-24 | Dropdown or popup menus (use bottom sheets) |
| AP-25 | Hiding the language toggle behind more than one tap from U1 |
| AP-26 | Glass bar opacity below 80% |
| AP-27 | Using `error` red for the Escalated status |
| AP-28 | Mixing driver sizes and user sizes on one screen |
| AP-29 | Covering the van marker with the sheet or nav (ignore map padding) |
| AP-30 | Inventing new tokens or colors instead of adding them to Section 2 first |

---

## 14. CHECKLIST (run on every screen, in light AND dark)

| # | Check | Y/N |
|---|---|---|
| 1 | Uses one shell from 3.2 with the correct nav rule (CL-27) | |
| 2 | Exactly one `primary` button, full-width pill (CL-07, CL-08) | |
| 3 | No literal colors, sizes, radii or text styles (CL-01 to CL-04) | |
| 4 | All text >= 14 sp (CL-05) | |
| 5 | All tappables >= 48 dp (driver 56) (CL-06) | |
| 6 | Statuses use `StatusChip` with color + icon + label (CL-09) | |
| 7 | Orange follows CL-11; `brandMid`/`brandLeaf` carry only ink text (CL-14) | |
| 8 | ContourCard present where required, at most one (CL-12, CL-13) | |
| 9 | Binny only where allowed, one per screen (CL-15) | |
| 10 | Cards radius 28, no borders, no dividers (CL-16, CL-30) | |
| 11 | Shadows only from the elevation tokens (CL-17) | |
| 12 | All strings localized, survive +50% length (CL-21) | |
| 13 | Language toggle reachable (CL-22) | |
| 14 | No gallery/picker anywhere in the report flow (CL-23) | |
| 15 | Loading, empty, error, offline states implemented (CL-24) | |
| 16 | Every tappable has a semantic label (CL-25) | |
| 17 | Pressed and focus states present (CL-29, 4.0) | |
| 18 | No horizontal page scroll (CL-26) | |
| 19 | Works at text scale 1.3 and 2.0 without clipping | |
| 20 | Both themes render with identical widget code (CL-20) | |
| 21 | Reduced motion respected (Section 8) | |
| 22 | Map overlays do not hide the van marker (CL-35) | |
| 23 | No raw error text shown (CL-28) | |
| 24 | Contrast verified against Appendix D | |

---

## 15. CONTENT ORGANIZATION (where things go)

### 15.1 Placement ladder (an action goes at the FIRST level that fits)

1. The one main task: primary CTA (bottom of M3, or inside the sheet on M1).
2. Closely related alternative: `secondary` or `tonal` directly under the primary.
3. Navigation to another area: pill nav (max 4 items).
4. Utility for this screen (refresh, recenter, language): round icon button in the glass bar or on the map.
5. Rare actions: a bottom-sheet menu opened from a 48 dp "more" icon button.
6. App-level settings: Settings screen.

### 15.2 Numeric thresholds

| Item | Threshold |
|---|---|
| Chips in a row-wrapped group | <= 5; 6+ becomes a bottom-sheet list with search |
| Pill nav items | 3 (max 4) |
| Header icon buttons | <= 2 |
| Bottom-sheet menu items | <= 7, max 2 groups |
| List page size | 10 |
| Card text lines | title 1-2, body <= 3 (ellipsis after) |
| Notice title | <= 40 characters |
| Primary buttons per screen | 1 |

### 15.3 Menu rules (mobile uses bottom sheets, never dropdowns)

| # | Rule |
|---|---|
| DD-1 | Menus open as a bottom sheet with a grab handle, radius 32 |
| DD-2 | Order: frequent actions, then secondary, then utilities, then destructive last |
| DD-3 | All items have a leading 24 dp icon, or none do |
| DD-4 | Labels: verb + noun, sentence case, <= 3 words |
| DD-5 | Item height 56; selected item shows a check icon, not bold |
| DD-6 | Destructive items are last, use `error` color + icon, and open a ConfirmDialog |
| DD-7 | Disabled items stay visible with a reason line |
| DD-8 | Long pickers (ward list) include a search field and show the current choice first |
| DD-9 | Never place the screen's primary action inside a menu |
| DD-10 | The trigger is a 48 dp icon button with a semantic label ("More options") |

### 15.4 Where does X go?

| Element | Location | Pattern |
|---|---|---|
| Report a problem | U1 sheet, primary | `primary` with camera icon |
| Van didn't arrive | U1 sheet, under primary | `accent` button, after scheduled start |
| Language | glass bar (U1), first-run, Settings | 4.18 toggle |
| Refresh / recenter | map overlay | round icon buttons |
| Ward change | Settings card + tap the glass bar title on U1 | ward picker sheet (DD-8) |
| Ticket status | complaint card + U4 | StatusChip, ContourCard |
| Rate service | U1 sheet after the van passes, or U5 | RatingStars |
| Theme | Settings | segmented Light / Dark / System |
| Notices (driver) | nav item + badge | M2 list |
| Mark ward done | D2 sheet, directly under the ContourCard | BigActionButton |
| End shift | D2 sheet primary, only once every ward is done -> D5 | BigActionButton label swap (changed 2026-10-28; was D2 "more" menu) |
| Tracking status | D2 glass bar | TrackingBadge |
| Help / privacy | Settings card | link row |
| Offline / stale | banner under the glass bar | 4.15 |

### 15.5 Layout arrangement rules

| # | Rule |
|---|---|
| LA-01 | Reading order = importance: status element, primary action, supporting cards, utilities |
| LA-02 | Primary action at the bottom, within thumb reach; destructive actions never at the bottom edge |
| LA-03 | One card = one topic. A card with two titles is split |
| LA-04 | Group by task, not by data model; related items within 12 dp, unrelated groups >= 24 dp |
| LA-05 | Equal-weight items use equal-size tiles on the same row |
| LA-06 | Progressive disclosure: summary first, detail on tap (U3 -> U4) |
| LA-07 | Never hide critical info (van status, offline, deadlines) in menus or tooltips |
| LA-08 | At most 3 cards visible without scrolling below the ContourCard |
| LA-09 | Align everything to the 20 dp page edge; full-bleed only for maps and the splash |
| LA-10 | Prefer whitespace to dividers (CL-30) |
| LA-11 | On the map, controls stack at the right edge, thumb-height: recenter above the sheet |
| LA-12 | Driver screens hold at most one decision at a time |

### 15.6 Navigation organization

| Surface | Items (left to right) |
|---|---|
| User pill nav | Map (`map`), My Complaints (`receipt_long`), Settings (`settings`) |
| Driver pill nav | Route (`route`), Notices (`notifications`), Reports (`report`) |

Active item: `primary` circle with `onPrimary` icon. State persists per tab (the map keeps its camera). The glass bar title area is tappable only on U1 (ward picker).

---

## APPENDIX A: Image element -> spec mapping

| Image element | Spec |
|---|---|
| Image 1: dark map with dots, glass top bar, black/white pill nav | 3.3, 4.5, 4.6, 4.10 |
| Image 1: big lime contour card with number and text | 4.9 (recolored green) |
| Image 1: small stat tiles with arrow button and dot texture | 4.8 |
| Image 1: forecast bar card | not used (no charts in these apps) |
| Image 2: splash with blob, illustration, black "Get Started" pill | 9.1, 4.1, 4.20 |
| Image 2: camera frame with corner brackets, chips, "Make a photo" pill | 4.12, 4.3, 9.4 |
| Image 2: white top sheet with avatar and text | 3.2 M4/M5, 4.8 |
| Image 2: map with pins, bin icon, comment field | 4.10, 4.4 |
| Image 2: orange selected chip and orange pin | 4.3, 4.10 |

## APPENDIX B: Values to verify against the designer's file (all `[est]`)

Brand greens, ink, page tint, orange, font family, hero number size, nav pill and glass bar sizes, contour line count and opacity. If a value is corrected, change ONLY Section 2 tokens; everything else inherits. Also verify on a real device: the map tile tint (D-12), glass blur performance on low-end phones, Material class names in 2.4, and the `flutter_svg` rendering of the four Binny files.

## APPENDIX C: Prompt to give the coding agent

```
Read DESIGN.md fully before writing code, then read PRD-1 (user app) or PRD-2 (driver app).
Follow Section 13 (rules, build order, folder structure, anti-patterns).
Task: build {screen ID and name} using its template in Section 9 and its shell in Section 3.2.
Use only tokens (Section 2) and components (Section 4). For placement of actions and menus use Section 15.
Use the Binny SVGs in assets/mascot only where Section 4.20 allows.
Implement loading, empty, error, offline states and both themes. Run Section 14 and fix every failed item before you reply.
If you need a UI element with no spec, add a spec to Section 4 first, then use it.
```

## APPENDIX D: Contrast report (WCAG 2.x, computed from the token values above)

| Pair | Ratio | Needs | Result |
|---|---|---|---|
| Light: textPrimary on background / surface | 15.40 / 16.78 | 4.5 | pass |
| Light: textMuted on background / surface / surfaceMuted | 5.86 / 6.39 / 5.53 | 4.5 | pass |
| Light: onPrimary on primary (ink) | 17.77 | 4.5 | pass |
| Light: onBrand (white) on brand | 5.38 | 4.5 | pass |
| Light: brand text on surface / background | 5.38 / 4.94 | 4.5 | pass |
| Light: ink on accent | 6.97 | 4.5 | pass |
| Light: WHITE on accent `#F0873A` | 2.55 | 4.5 | FAIL, forbidden (D-03) |
| Light: white on accentStrong / accentStrong on surface | 5.38 / 5.38 | 4.5 | pass |
| Light: ink on brandMid | 7.05 | 4.5 | pass |
| Light: WHITE on brandMid | 2.52 | 4.5 | FAIL, forbidden (D-08) |
| Light: status text on soft (received / assigned / resolved / escalated) | 5.29 / 6.23 / 5.64 / 5.37 | 4.5 | pass |
| Light: borderStrong on surface / background | 3.75 / 3.44 | 3.0 | pass |
| Light: status fill on surface (received / assigned / resolved / escalated); lowest on background 3.37 | 3.67 / 4.72 / 4.14 / 4.77 | 3.0 | pass |
| Dark: textPrimary on background / surface | 16.06 / 14.34 | 4.5 | pass |
| Dark: textMuted on background / surface / surfaceMuted | 8.02 / 7.17 / 6.29 | 4.5 | pass |
| Dark: onPrimary on primary | 16.91 | 4.5 | pass |
| Dark: onBrand on brand | 7.29 | 4.5 | pass |
| Dark: brand text on surface / background | 7.86 / 8.80 | 4.5 | pass |
| Dark: accentStrong text on surface | 7.93 | 4.5 | pass |
| Dark: status text on soft (received / assigned / resolved / escalated) | 8.47 / 6.74 / 7.35 / 7.08 | 4.5 | pass |
| Dark: error on surface | 8.09 | 4.5 | pass |
| Dark: borderStrong on surface | 3.50 | 3.0 | pass |
| Dark: status fill on surface (received / assigned / resolved / escalated) | 7.72 / 5.19 / 6.15 / 5.41 | 3.0 | pass |

## APPENDIX E: Assets and packages

`pubspec.yaml` must declare: fonts `NotoSans` and `NotoSansGujarati`; assets `assets/mascot/` and `assets/fonts/`. Packages: `flutter_svg`, `flutter_map`, `latlong2`, `flutter_riverpod`, `intl`, `flutter_localizations` (PRD lists the Firebase and location packages). Icons: use the `material_symbols_icons` package (outlined, weight 300) or Flutter's built-in `Icons.*_outlined` if the package is not available; keep 24 dp.
