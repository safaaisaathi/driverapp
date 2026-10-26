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
- [ ] Delete dev entrypoints at integration: `dev_tracking.dart`, `dev_pending_reports.dart`, `dev_live_route.dart`, `dev_notices.dart`, `dev_min.dart`. *(me → 14)*
- [ ] Index seeds for Backend Owner: notices OR-branch sort, pending-reports `(wardId, createdAt)`, trip `(vanId, date)` (rulings 10/11/16). *(Backend Owner)*
- [x] Real Firebase config: **delivered 2026-10-26** — Android app `1:179594621556:android:8bdac1de2d29745aad1721` registered on `safaaisaathi-63a87` via `flutterfire configure`; CLI logged in as the owner's Google account. Values reach the app at RUN TIME via dart-defines `DRIVERAPP_FB_API_KEY` / `_FB_APP_ID` / `_FB_SENDER_ID` (see `sharedProjectFirebaseOptions()`) — **no keys in the repo** (§0.10); generated files (`lib/firebase_options.dart`, `google-services.json`, `firebase.json`) are gitignored. Run with `--dart-define=DRIVERAPP_USE_EMULATOR=false` + the 3 value defines; the ready-made command was kept in a private local note (NOT the repo) — regenerate from the untracked `lib/firebase_options.dart` if the note is lost. Gradle `google-services` plugin deliberately NOT applied (fresh clones build without the private JSON). *(me)*
- [x] Integration: insert `MockLocationWarningBanner(vanId: vanId)` at top of D2's body `Column` (ticket 11 report §c) when D2 merges. *(me — at 06 merge)* — DONE at the 06 merge; covered by full-suite gates.
- [ ] Day-window seam semantics (from ticket 10): repo day/date params bracket by the passed value's LOCAL calendar fields; fed a `trips.date`-shaped instant (ruling 9) the range can land on the previous local day, and a stored `trip.date` can sit exactly on the exclusive `dayEnd` and never match (ticket-04 fake passes only by date-vs-date field equality). Decide: fix repo seam or rule it — LASTLY verify on device at rehearsal. *(me → 14 / Backend Owner)*

### Feature Bag
- [ ] Notices read-state is session-local — the 0.2 `notices` shape has NO read field, so unread markers reset on restart/shift end (red test pins mark-read writes nothing). Persistent unread needs a contract field from Backend Owner. *(Backend Owner)*
- [ ] Staff push on mock-location detection — no contract Cloud Function exists (ruling 7). *(Backend Owner)*
- [ ] Notices push parity — driver-device topic-only for now. *(Backend Owner)*
- [ ] Deploy real `verifyDriverPin` callable + seed vans docs (shaped per 0.7; emulator port 5001 wired, code-mapping switch marked "refine with Backend Owner"). *(Backend Owner)*
- [ ] `connectivity_plus` dependency sits outside the 0.6 package list — record sign-off. *(Backend Owner)*
- [ ] `shared_preferences` dependency sits outside the 0.6 package list — record sign-off alongside `connectivity_plus`. *(Backend Owner)*

### Walkthrough findings folded in (2026-10-26 session)
- [x] **ContourCard canvas leak**: the contour painter's rings (≤0.9 × longest side) painted across the WHOLE window — a `BoxDecoration` alone never clips children. Fixed with `clipBehavior: Clip.antiAlias` on the Container (`lib/core/widgets/contour_card.dart`); verified live (rings gone from the map, contours confined per CL-12).
- [x] **Theme min-size crash**: `minimumSize: Size.fromHeight(h)` sets width=∞ → `BoxConstraints(w=Infinity)` crash inside Rows (route-complete card). Fixed to `Size(0, h)` at 3 sites in `app_theme.dart`. LESSON: never Size.fromHeight for button minimumSize.
- [x] **Next-ward auto-reveal** (DESIGN.md "content never covered by nav", line 365): `WardListPanel` keeps the canonical `liveRoute.wardRow.{id}` key on an inner Container while a `KeyedSubtree`+GlobalKey on the highlighted row `Scrollable.ensureVisible`s above the nav reserve post-frame (guarded `_autoRevealedFor`). Widget tests CANNOT catch nav occlusion — needs a real window (rule 0 vindicated).
- [x] **Android location permissions** declared in the manifest (`ACCESS_COARSE/FINE_LOCATION`, commit 06bd098): geolocator requested at runtime but silently denied without manifest entries — the phone will now show the real dialog.
- Device-rehearsal environment (logistics, not contract): phone links over **Wi-Fi adb** (`adb connect`, then `-d <ip>`); `~/tools/adbfs-rootless/adbfs` mounts storage at `~/phone`; the self-healing link is `~/.local/bin/phone-link.sh`, auto-started at login (`~/.config/autostart/phone-link.desktop`). **Build protocol under flaky restarts: use `flutter build apk --debug` + `flutter install` instead of `flutter run -d`** — a mid-run server restart kills the Gradle daemon otherwise (`android/gradle.properties` now carries artifact-download retry flags after ISP-side TLS resets on dl.google.com).

### Standing protocol (recorded 2026-10-24)
0. **USER VERIFICATION FIRST (directive 2026-10-25): after a feature (or the whole app) finishes building, verify it AS A USER WOULD — open the running app, click through the feature, judge by what appears on screen. Green tests/analyze are necessary but NOT verification.** Loop: launch window (or device) → screenshot → interact (xdotool clicks/taps on-adapted for desktop; real finger on device) → screenshot → assert visible behavior. Dev entrypoints drive feature-level checks offline (Firebase has no desktop plugin — main() shows a bootstrap error on Linux); full user-loop runs on Android device at ticket 14.
1. Agent reports → gate (analyze + test in worktree) → merge → full-suite gate on main → **user verification of the merged feature (rule 0)** → rulings + glossary fold with bags updated.
2. Next frontier wave launches immediately (dependency table in `.scratch/driver-app/README.md`).
3. TDD from ticket 12 onward: failing tests first.
4. Ticket 14 (serial, last): integration rehearsal, real-phone stabilization, delete dev entrypoints.
5. Pentest after 14: auth/token abuse, Firestore rules red-team (foreign van/trip/complaint writes, `currentTripId`/`mockLocationDetected`), verifyDriverPin rate-limit/replay, input validation, mock-location adversary. Findings → Bug Bag, fixed on `feat/` branches.
6. Post-completion changes go through `feat/*` / `fix/*` branches only; no direct pushes to main.
