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
| 8 | `vans.currentTripId` not listed among driver writes in 0.13 table | Behaviour rules (§3) explicitly have the app set `currentTripId` at start / clear at end — sanctioned. Backend Owner must ensure Firestore rules allow it (0.8 summary omission). |
| 9 | `trips.date` storage encoding | Firestore Timestamp at 00:00 IST (IST-resolution of "Today" lives in the domain layer). |
| 10 | Notices inbox composite index | Repo filters OR-branches in Firestore, sorts newest-first inside repository; Backend Owner seeds any needed index (`firestore.indexes.json`). |
| 11 | Pending-reports index (day-range + `whereIn(wardId)`) + two-`whereIn` impossible | Statuses filtered in repository post-query; Backend Owner seeds `(wardId, createdAt)` composite index. |
| 12 | `whereIn` 30-value cap | Routes >30 wards: chunking acceptable, documented exception for a later ticket. |
| 13 | `wardsDone` idempotency (retried Mark → duplicate entry) | Client dedupes by `wardId` (skip if already done this trip); offline-sync ticket must preserve that. |
| 14 | `gpsTrail.t` type / `batteryPct` type | Timestamp semantics / int 0–100. |
| 15 | Doc `id` as a stored field | Mirrored in `toMap`; seeds keep doc id == stored `id` (as `vanSecrets` id implies). |
| 16 | Trip watch query needs `(vanId, date)` composite index at scale | Flagged for Backend Owner; no contract-field additions. |
| 17 | Mock-location latch mechanics | The `trips.mockLocationDetected` doc field IS the latch (read_model, kill/restart safe, idempotent writes); local engine flag only prevents redundant writes, cleared on hard write error → next mocked fix retries. App never writes `false`. Ruling 7 stands: no staff push. |
| 18 | `trips.startedAt` clock source | Client clock at Start Shift (models carry `DateTime`, not a server-timestamp venue); `date` uses `utcStartOfIstDay` of that instant. If the Backend Owner wants server truth, `startedAt` becomes server-timestamp on trip create — contract-safe, flag at review. |
| 19 | Offline catch-up batching (F-D7) | Catch-up uses the SAME repository `appendGpsTrail` pattern; chunks ≤ `maxCatchUpBatchPoints` (500, developer bound — Backend Owner may veto); a failed append puts its batch back at the FRONT and STOPS the drain (no later batch runs past a failed earlier one); the `vans.lastLocation` queue is latest-only (never re-send older after newer landed). |

ADR candidates still open: resume-vs-duplicate-trip (04), out-of-order ward marking (07).
