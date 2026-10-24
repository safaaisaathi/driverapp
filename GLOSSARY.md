# Glossary

Domain terms for the **Driver App (Garbage Van)** context of the Citizen-Centric Garbage Collection and Sanitation Monitoring System (source of truth: `docs/PRD-2-driver-app.md` section 0). This file is also the single home of the four bags — their live state lives at the bottom and must be updated with every merge.

## Language

**Van**:
A garbage collection vehicle. One van serves one route and carries one tracked Android phone.
_Avoid_: truck, vehicle

**Ward**:
A mapped area (centre + radius) whose garbage collection is served by one route and supervised by one inspector.
_Avoid_: zone, area

**Route**:
The visiting order a van follows: one route is the ordered list of wards.
_Avoid_: schedule, path

**Shift**:
The driver's working session, from Start Shift to End Shift.
_Avoid_: session, duty

**Trip**:
The log record of one shift: the van's trail, the wards done, and alert history.
_Avoid_: journey, ride

**Mark Ward Done**:
The driver's action that records a ward as collected during the current trip.
_Avoid_: tick, check-in

**Flagged**:
A Mark Ward Done made from outside that ward's radius, kept for admin review.
_Avoid_: suspicious, invalid

**Notice**:
A one-way message an admin sends to a van, to a ward, or to everyone.
_Avoid_: announcement, alert

**Pending Report**:
A missed-collection complaint for today's route wards that awaits driver action.
_Avoid_: backlog, open ticket

**Today**:
The collection-day calendar date, resolved in Asia/Kolkata regardless of phone clock settings.
_Avoid_: current date

**Write Policy**:
The rule that limits location writes: write only if the van moved at least 15 m since the last write, or 30 s passed since then, so a stopped van never looks dead.
_Avoid_: throttle, GPS rule

**Trail**:
The ordered series of location points recorded during a Trip.
_Avoid_: track log, route history

**Mock Location**:
A position fix the phone's provider marks as mocked (spoofed). Detection latches for the trip: `trips.mockLocationDetected` set true, never unset by the app; driver sees a warning banner.
_Avoid_: fake GPS, spoofing

**Shift Session**:
The signed-in shift context the app holds in memory: vanId, tripId, routeId, startedAt (the `ShiftController` provider). Screens and the tracking engine read it; End Shift clears it.
_Avoid_: login state, user data

## Bags (live state)

Deferred work parking lot. Sweep at wave boundaries; every item moves out only when shipped, or ships as `shortcut:` code. Owner: me (agent), Backend Owner, or user.

### Performance Bag
- [ ] `maxTrailBufferPoints` (5000) cap is a guess — measure real batch write latency on device (ticket 14). *(me → 14)*
- [ ] `gpsTrail` arrayUnion grows one doc unbounded long-shift — contract change, shard/rotation. *(Backend Owner)*
- [ ] D2 runs van + trip + route + wards listeners concurrently — measure cold-start on emulator/phone. *(me → 14)*
- [ ] Map package is `flutter_map` (zero-key pick); revisit if PRD pins Google Maps. *(me → 14)*

### Bug Bag
- [ ] Test-timer collision relies on event-loop FIFO — could flake on slow CI; fix with flush-interval offsets if seen. *(me)*
- [ ] Banner (mock-location) can render for seconds after End Shift while D2 stays mounted — D2 disposes on navigation; harmless, watch during rehearsal. *(me → 14)*
- [ ] `connectivity_plus` reports interface presence, not internet reachability — harmless (failed writes re-queue); rehearsal must test real airplane-mode. *(me → 14)*
- [ ] `LocaleController` restore is fire-and-forget — very slow disk can render `en` for the first frame(s) before a stored `gu` lands (self-correcting); watch during rehearsal. *(me → 14)*

### Improvement Bag
- [ ] Locale flip `en` → `gu` before demo (grilled decision; arb files ready). *(me)*
- [ ] `whereIn` >30-ward chunking (ruling 12) — build when demo routes exceed 30 wards. *(me)*
- [ ] Delete `dev_tracking.dart` + dev entrypoints at integration. *(me → 14)*
- [ ] Index seeds for Backend Owner: notices OR-branch sort, pending-reports `(wardId, createdAt)`, trip `(vanId, date)` (rulings 10/11/16). *(Backend Owner)*
- [ ] Real Firebase keys: paste at `sharedProjectFirebaseOptions()`, run `--dart-define=DRIVERAPP_USE_EMULATOR=false`. *(user)*
- [ ] Integration: insert `MockLocationWarningBanner(vanId: vanId)` at top of D2's body `Column` (ticket 11 report §c) when D2 merges. *(me — at 06 merge)*

### Feature Bag
- [ ] Staff push on mock-location detection — no contract Cloud Function exists (ruling 7). *(Backend Owner)*
- [ ] Notices push parity — driver-device topic-only for now. *(Backend Owner)*
- [ ] Deploy real `verifyDriverPin` callable + seed vans docs (shaped per 0.7; emulator port 5001 wired, code-mapping switch marked "refine with Backend Owner"). *(Backend Owner)*
- [ ] `connectivity_plus` dependency sits outside the 0.6 package list — record sign-off. *(Backend Owner)*
- [ ] `shared_preferences` dependency sits outside the 0.6 package list — record sign-off alongside `connectivity_plus`. *(Backend Owner)*

### Standing protocol (recorded 2026-10-24)
1. Agent reports → gate (analyze + test in worktree) → merge → full-suite gate on main → rulings + glossary fold with bags updated.
2. Next frontier wave launches immediately (dependency table in `.scratch/driver-app/README.md`).
3. TDD from ticket 12 onward: failing tests first.
4. Ticket 14 (serial, last): integration rehearsal, real-phone stabilization, delete dev entrypoints.
5. Pentest after 14: auth/token abuse, Firestore rules red-team (foreign van/trip/complaint writes, `currentTripId`/`mockLocationDetected`), verifyDriverPin rate-limit/replay, input validation, mock-location adversary. Findings → Bug Bag, fixed on `feat/` branches.
6. Post-completion changes go through `feat/*` / `fix/*` branches only; no direct pushes to main.
