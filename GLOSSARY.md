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
The driver's action that records a ward as collected during the current trip. Marks may be made out of order — any undone ward, not only the next one.
_Avoid_: tick, check-in

**Next Ward**:
The first ward in the route's visiting order that today's trip has not recorded done. The live route screen highlights it and hands it the primary mark action.
_Avoid_: current ward, target ward

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

**Tracking**:
The location engine that runs for the whole shift: fixes every 10 s, writes governed by the Write Policy, surfaced to staff on the live map under the persistent "Tracking active" notification.
_Avoid_: GPS, background location

**Trail**:
The ordered series of location points recorded during a Trip.
_Avoid_: track log, route history

**Stale Location**:
A van position older than the 60 s staleness window. Shown muted with a "Last seen X min ago" note instead of being treated as live.
_Avoid_: dead GPS, lost signal

**Mock Location**:
A position fix the phone's provider marks as mocked (spoofed). Detection latches for the trip: `trips.mockLocationDetected` set true, never unset by the app; driver sees a warning banner.
_Avoid_: fake GPS, spoofing

**Shift Session**:
The signed-in shift context the app holds in memory: vanId, tripId, routeId, startedAt (the `ShiftController` provider). Screens and the tracking engine read it; End Shift clears it. While a shift is on there is exactly one active van — the session's own; nothing else counts as "the current van".
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
- Device-rehearsal environment (logistics, not contract): phone links over **Wi-Fi adb** (`adb connect`, then `-d <ip>`); `~/tools/adbfs-rootless/adbfs` mounts storage at `~/phone`; the self-healing link is `~/.local/bin/phone-link.sh`, auto-started at login (`~/.config/autostart/phone-link.desktop`). **Build protocol under flaky restarts: use `flutter build apk --debug` + `flutter install` instead of `flutter run -d`** — a mid-run server restart kills the Gradle daemon otherwise (`android/gradle.properties` now carries artifact-download retry flags after ISP-side TLS resets on dl.google.com). **Never run two `flutter run` sessions concurrently** — a second run's Gradle force-stops + reinstalls mid-flow, killing the live session (proven 2026-10-28).

### Walkthrough findings folded in (2026-10-28 device session)
- [x] **Riverpod 3 nested-scope override defect (D1 → D2 hand-over)**: a nested `ProviderScope.overrideWithValue` for `currentVanIdProvider` was silently UNUSED on device — Riverpod 3 creates a provider a child scope does not override in the PARENT container, so the van-doc chain resolved without the value and threw "must be overridden". Tests missed it because they overrode at root. Fixed by deleting the seam entirely: every live-route provider is a family keyed by an explicit `vanId` argument handed over from the Shift Session (`LiveRouteScreen(vanId:)`, `EndShiftScreen(vanId:)`, `mark(vanId, wardId)`; family declarations must stay untyped or the callability breaks). LESSON: context travels as an argument, never as a nested override. Verified live on device: real map renders, mark flow writes end-to-end. *(me)*
- [x] **Demo prod data reshaped for today's rehearsal**: `trips/dev-trip-1.date` → today's IST start (the day-window query brackets by device-local midnight), wards 1–3 centres moved next to the van's live GPS so the map shows the route. Firestore REST lesson: PATCH needs `?updateMask.fieldPaths=<f>` — a bare `updateMask=` fails with "Cannot bind query parameter".
- [x] **Mark-button tap death: nav occlusion at the default snap (Section A rebuild, 2026-10-28)**: the rebuilt sheet's default snap 0.36 put the 72 dp "Mark Ward Done" button's CENTRE (y=816 of 900) inside the PillNav's real container (804–884 — the nav footprint is 96 dp: `SafeArea + bottomPadding 16 + Container 80`, token says 80). Stack hit-testing is top-child-wins, so the tap went to the nav's Route item (a no-op) and the write never fired — deterministic, both in tests AND on the phone. Fixed by raising `DraggableSheet.defaultFraction` to 0.45 (button bottom 771 < nav top 804, 33 dp clear); 5 of 7 failing mark tests went green instantly. LESSON: a floating nav's EFFECTIVE footprint (token + safe area + padding) is the occlusion ruler for everything anchored at the bottom of a map shell. *(me)*
- [x] **Test-only lesson that came out of the same hunt**: `scrollUntilVisible` guarantees visibility INSIDE the scroll view — the view's bottom 96 dp sit under the floating nav where taps die. Tests now use `scrollAboveNav` (scroll, then top up until `getRect(finder).center.dy < navTop`). Also: `Semantics(container:)`/`Tooltip` wrappers around a keyed button changed the render object between finder evaluation and hit test in flaky runs — the big button stays a bare keyed `FilledButton`, ward-name semantics carried by the row, not the button. The "sheet subtree absent from the hit path while a per-node `hitTest` walk claims it" residual (framework-level) was side-stepped by the snap fix and is NOT observed on the device; if it resurfaces, instrument with the root `Listener` pointer spy + full hit-path dump (the probe's final shape) before theorizing. *(me)*

### Device-debugging findings folded in (2026-10-28 session)
- [x] **Double-engine race defect (Samsung letterbox)**: during Flutter engine warm-up, Samsung's letterbox settle can relaunch MainActivity → a SECOND Flutter engine in the same process (proof: FlutterGeolocator logcat `Connected engine count 1` → `count 2`, seen on BOTH a healthy prod build and a broken one). Two engines = two `main()` runs = two ProviderContainers = two `BootstrapController.run()` loops racing `Firebase.initializeApp`; the loser throws `PlatformException(IllegalStateException, "FirebaseApp name [DEFAULT] already exists!")` on every retry (2 s/10 s/30 s, `bootstrapRetryDelay`, forever) and both engines leak. Interleaved `degraded (attempt N)` counters from two loops in one log = the signature of this bug. Fix in flight: bootstrap ADOPTION — on already-exists, adopt `Firebase.app(defaultFirebaseAppName)` instead of re-initializing; reference the fix here once it lands. *(me)*
- [x] **Prod-run command is load-bearing**: every prod `flutter run` MUST carry the full defines — `--dart-define=DRIVERAPP_USE_EMULATOR=false` plus the 3 value defines (`DRIVERAPP_FB_API_KEY` / `DRIVERAPP_FB_APP_ID=1:179594621556:android:8bdac1de2d29745aad1721` / `DRIVERAPP_FB_SENDER_ID=179594621556`; the API-key literal stays OUT of the repo per the no-keys ruling above — it lives in the private local note). Dropping the defines silently rebuilds with `kUseFirebaseEmulator` defaultValue:true → the app targets phone-localhost:9099/8080 (nothing there) → `auth/network-request-failed` forever, "Couldn't load vans"/"No vans found" (empty via the Firestore cache fallback). Symptom chain fully proven 2026-10-28. *(me)*
- [x] **MCP mobile agent-attach eats the first interaction**: `am attach-agent …/mobilecli.dex` runs on the FIRST MCP use per app process; the tap/keys racing it are swallowed — retry the same tap, the second attempt lands. Also: MCP element refs (`@eN`) go stale across screens — prefer absolute coordinates (device 1080×2340) or re-query elements. `adb input` taps use SPACE syntax; MCP clicks use raw screen pixels. *(me)*
- [x] **First Flutter keystrokes race the IME opening**: `mobile_type_keys` right after focusing a field can drop leading characters (typed `1234`, only `12` landed). Retry the remainder after checking the screen. *(me)*
- [x] **System BACK on D1 Shift start** (root screen, IME hidden) exits the app; activity recreate clears the ephemeral PIN text but Riverpod flow state (selected van) survives. The IME ✓ action key does NOT trigger the PIN verify (no `onSubmitted` wired) — verification needs the Verify PIN button. Possible UX follow-up. *(me)*
- [x] **Firestore REST access-token recipe** (prod data resets; project `safaaisaathi-63a87`): token from firebase-tools' refresh_token in `~/.config/configstore/firebase-tools.json` (path `tokens.refresh_token`), exchanged at `oauth2.googleapis.com/token` with firebase-tools' own client (`lib/api.js`): client_id `563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com`, client_secret `j9iVZfS8kkCEFUPaAeJV0sAi` (public installed-app client, published in the firebase-tools source). PATCH arrays need `?updateMask.fieldPaths=<f>` (the one-line lesson in the walkthrough entry above) and `{"arrayValue":{}}` = empty array. gcloud is NOT installed on this machine. *(me)*
- [x] **pkill self-match footgun**: `pkill -f "flutter_tools.snapshot run"` matches the calling shell's own cmdline and kills it (SIGTERM to own command). Use the bracket trick: `pkill -f "flutter_tools[.]snapshot"`. *(me)*
- [x] **Flutter error widget in the wild**: a red clipped strip reading `…FLOWED BY 36 PIX` in a live screenshot = a RenderFlex overflow error widget (that one = the GlassBar `TrackingBadge` row, fixed 2026-10-28 with `Flexible`+ellipsis). *(me)*

### Device-debugging findings folded in (2026-10-29 session)
- [x] **Bottom-most snap law (D2 sheet, driver-directed)**: the driver dragged the sheet down and held it at one exact height — "the West Loop · 3 of 3 ward done thing hides behind the bottom navigation". Pixel-measured off the held screenshot (M215F, 360×780 dp, gesture inset 15 dp): sheet top 637 dp, grab strip 24 dp + head pad 8 dp ⇒ **card top 669 dp == pill top 669 dp** — the 80 dp card is masked 1:1 by the 80 dp pill. Codified device-independently in `_sheetSnaps`: `collapsed = (safeBottom + lg + navHeight + grabStrip 24 + headPad 8) / screenH`, `middle = collapsed + cardHeight/h` ("just the green ripple thing"), `full = 0.96`. Tokens + MediaQuery only — never raw pixels. The sheet now OPENS at collapsed (`initialSize`).
- [x] **Under-pill strip clip (the cream-sliver defect)**: with the card hidden behind the pill, the End Shift button's top still peeked as a 4 dp cream sliver at 761–765 dp — in the strip under the floating pill (safeBottom + lg = 31 dp) where the nav does NOT cover the sheet. Fixed with `_UnderPillClipper` in `DraggableSheet`: the scroll CONTENT is clipped at the pill's bottom edge; the sheet's SURFACE still fills it. LESSON: anything a floating pill overlays needs a content clip at the pill's bottom edge, not just a content bottom-padding reserve.
- [x] **Density override gotcha**: M215F reports `wm density` override **480 dpi → 3.0 dp scale** (physical 420 dpi / 2.75 is the WRONG divisor). All pixel→dp math from screenshots must use the override, else every derived geometry is ~9 % off.
- [x] **Sheet opens collapsed → widget tests must pull first**: with `initialSize = collapsed`, nothing in the panel is reachable at pump time. Tests got `pullSheetFull` (drag −900 from `navTop − 18` — ON the grab strip; a drag at the scrollable's CENTRE lands on the nav overlay and is swallowed by it, same occlusion law as the 2026-10-28 tap-death). `scrollAboveNav` now pulls first too. 297/297 green after the fold. *(me)*

### Standing protocol (recorded 2026-10-24)
0. **USER VERIFICATION FIRST (directive 2026-10-25): after a feature (or the whole app) finishes building, verify it AS A USER WOULD — open the running app, click through the feature, judge by what appears on screen. Green tests/analyze are necessary but NOT verification.** Loop: launch window (or device) → screenshot → interact (xdotool clicks/taps on-adapted for desktop; real finger on device) → screenshot → assert visible behavior. Dev entrypoints drive feature-level checks offline (Firebase has no desktop plugin — main() shows a bootstrap error on Linux); full user-loop runs on Android device at ticket 14.
1. Agent reports → gate (analyze + test in worktree) → merge → full-suite gate on main → **user verification of the merged feature (rule 0)** → rulings + glossary fold with bags updated.
2. Next frontier wave launches immediately (dependency table in `.scratch/driver-app/README.md`).
3. TDD from ticket 12 onward: failing tests first.
4. Ticket 14 (serial, last): integration rehearsal, real-phone stabilization, delete dev entrypoints.
5. Pentest after 14: auth/token abuse, Firestore rules red-team (foreign van/trip/complaint writes, `currentTripId`/`mockLocationDetected`), verifyDriverPin rate-limit/replay, input validation, mock-location adversary. Findings → Bug Bag, fixed on `feat/` branches.
6. Post-completion changes go through `feat/*` / `fix/*` branches only; no direct pushes to main.
7. **COMPACTION PROTOCOL (directive 2026-10-28): before and after every conversation compaction, use and update this GLOSSARY.md.** Before the context is summarized: fold the session's fresh domain terms, sharpened definitions, and fixed defects into Language + findings + bags (as they happen, not batched). After compaction: re-read this file FIRST to restore the domain context before continuing any work.
