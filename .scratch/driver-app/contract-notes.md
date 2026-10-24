# Contract notes & rulings

Ambiguities surfaced by implementation. Defaults below follow the PRD wording; the owner can veto any of them — contract changes go through the Backend and Integration Owner (0.15.4).

| # | Ambiguity | Ruling taken (until owner overrides) |
|---|-----------|--------------------------------------|
| 1 | `lastWritten != null` but `lastWriteTime == null` (heartbeat undecidable) | Movement rule alone decides; unmoved → skip. In practice the app always knows its own last write time. |
| 2 | Does the GPS sampling interval also gate writes? | No — the interval is cadence-only; movement OR heartbeat gates the write (matches "write only if moved … or HEARTBEAT_SEC"). |
| 3 | Battery exactly = `LOW_BATTERY_PCT` (20) | Strictly `<` counts as low; `== 20` uses the normal interval. |
| 4 | Ward-radius boundary (point exactly `radiusM` away) | `isWithinWard` inclusive (`<=`), flagged only strictly outside. Floating-point exact-coincidence is undefined. |
| 5 | `outOfOrderWardIds` definition (grilled decision) | Undone wards other than the first-undone (next-in-order). Unknown done ids ignored; duplicate ids in `routes.wardIds` → first occurrence wins. |
| 6 | "Last seen X min ago" rounding | Floors, clamped ≥ 0. |
| 7 | Mock-location admin push | No contract Cloud Function exists; driver sets `trips.mockLocationDetected` + in-app warning; push-to-staff referred to Backend Owner. |

ADR candidates still open: resume-vs-duplicate-trip (04), out-of-order ward marking (07).
