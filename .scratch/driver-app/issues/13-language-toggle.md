# 13: F-D10 Language toggle

**What to build:** Gujarati/English toggle on D1 (grilled decision: dev-phase default remains `en`; the pin is removed before the demo). Selection persists across launches and applies app-wide instantly (no restart); all strings stay through l10n (0.11). Android launcher name follows system locale (values-gu already in place).

**Blocked by:** 04 (D1 exists).

**Status:** ready-for-agent

- [ ] Toggle on D1 switches every visible string immediately and persists across restart
- [ ] `en` default holds during development per the grilled decision (pin still flagged for pre-demo removal)
- [ ] Gujarati rendering verified (Noto Sans Gujarati shapes) on D1/D2 at minimum
- [ ] Widget test (seam 1): locale switch flips localized labels; persistence mechanism covered
