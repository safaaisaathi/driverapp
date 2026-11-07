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

**Depot dwell (auto-end)**:
The rule that ends a shift by itself when the van stays inside 500 m of its depot for 3 hours non-stop. The depot is the admin-set `vans.depot = {lat, lng}` tag; leaving the radius or moving 100 m restarts the 3-hour clock.
_Avoid_: parking timeout, idle shift

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

### Driver-identity wave (in progress, overnight 2026-10-30)

Login architecture change: driver enters a unique code `XX-0000` (admin allots van + wards in `drivers/{CODE}`), confirm card, straight to shift. Spec = GitHub issue #1; tickets = sub-issues #2-#10 with native blocking edges. Branch `feature/driver-identity`, PR to `main` at the end (user approves; never self-merge). Contract frozen in PRD-2 §0.16 BEFORE code. Visual spec: `docs/DESIGN-driver-app.md` (wireframe-derived, DESIGN.md structure, rulings D-101..D-108). Tracking: old D1 (van picker + PIN) dies; splash auto-routes on a device-local `setupDone` flag; Binny mascot removed everywhere ([removed-T8] in the design file; empty states need the neutral-icon replacement). Tickets so far: 1 contract+rules+seeds ✅ (#2), 2 Driver model + DriversRepository ✅ (#3, named per codebase convention, not "DriverDirectory"), 3 identity persistence ✅ (#4), 4 start-shift page ✅ (#5), 5 welcome-back card ✅ (#6), 6 fresh-device path ✅ (#7; Start Duty screen deleted, dev preview on the new chain), 7 trip contract driverId+wardIds + D2 ward scoping ✅ (#8, Tier 2 fixes in flight: empty-wardIds scope leak, resume reconcile, route-order filter), 8 splash auto-route + mascot removal ✅ (#9, cap 1.6 s), 10 smart code keyboard ✅ (#11, keyboard flips letters→digits, dash auto-inserts after the 2nd letter, 44 tests green), 9 integration verify ✅ (#10, 2026-10-31: fresh + returning device paths, change-code/back nav, offline failure card, resume on an open real trip, and D2 scoping verified on the M215F against the real trip `X4e68Ep69H2whABl2rqf` (`driverId: AB-1001`, `wardIds: ["ward-1"]`); bag sweep spec #12 shipped on `bag/trips-day-window` (stacked PR) via issues #15, #13, #24, #25). Old `verifyDriverPin` Function stays deployed until the Backend Owner sweep (app stops calling it).

### Performance Bag
- [x] `maxTrailBufferPoints` (5000) cap + batch write latency — MEASURED ON DEVICE 2026-10-31 (issue #13, M215F, real project): 100 pts (~5 KB) 1.7 s · 1000 pts (~53 KB) 8.0 s · 2500 pts (~133 KB) missed a 25 s deadline (landed ~40 s later) · 5000 pts (~265 KB) stalled the write stream past a minute. The constant was DEAD (no code read it) and each 30 s flush wrote the whole buffer. Resolution: `maxTrailBatchPoints = 1000` per flush (oldest first, a backlog drains in measured batches), `maxTrailBufferPoints` (5000) enforced by `HiveTrailBuffer.add` (oldest dropped), one flush write at a time, `stop()` drains batch by batch. 432/432 green. *(me → 14)*
- [ ] `gpsTrail` arrayUnion grows one doc unbounded long-shift — contract change, shard/rotation. Measurement now bounds the WRITE (1000 pts ≈ 53 KB ≈ 8 s), not the doc growth: 5 h at 1 Hz ≈ 18 k pts ≈ 1 MB, at the 1 MiB doc limit (backend admin write of 5000 pts took 3.3 s). *(Backend Owner)*
- [x] D2 runs van + trip + route + wards listeners concurrently — MEASURED 2026-10-31 (issue #13, M215F): 2.3 s median from screen entry to the first data frame (2331 / 2453 / 2317 ms, warm Firestore client after bootstrap). A cold-client probe measured 7.9 s, so the warm number is the user-visible one; no code change. *(me → 14)*
- [x] Map package is `flutter_map` (zero-key pick) — CLOSED AS DECIDED 2026-10-31: the PRD pins no Google Maps, so the zero-key pick stands; no measurement, no code. *(me → 14)*

### Bug Bag
- [x] D2 tracking banner overflowed 20 px at 360 dp — RESOLVED 2026-10-31 (issue #24): message row + wrapping action row; 360 dp widget test pins it; device-verified on the M215F (gps-off banner, both actions reachable).
- [x] Today's-trip read could return a closed same-day sibling — RESOLVED 2026-10-31 (issue #25): `watchTripByVanIdAndDate` returned `docs.first` with no ordering, so a closed trip (`wardsDone: [ward-1]`) shadowed the open one and D2 showed a stale done tick. The read now prefers the open trip, else the latest start; the fake mirrors it; both rules tested. Device-verified: "0 of 1 wards done" on the open trip.
- [x] Test-timer collision relied on event-loop FIFO — RESOLVED 2026-10-29: drain assertion rewritten outcome-based (bounded 10 s poll until both trail points land, then order asserted); no prod change, no timer offsets. 301/301 green.
- [x] Banner could render after End Shift while D2 stayed mounted — RESOLVED 2026-10-29: banner gated on the live shift session (`session != null && session.vanId == vanId`); trip-doc latch contract untouched (admin still sees the flag). 2 new widget tests (ended session hides; other van's session hides).
- [x] `connectivity_plus` reports interface presence, not internet reachability — CLOSED BY DESIGN 2026-10-29: no reachability probe (battery cost on a driver phone, zero correctness gain; failed writes re-queue with order preserved). Ticket-14 rehearsal step added: airplane-mode ON mid-shift → offline banner + queue grows → airplane-mode OFF → queue drains in order, lastLocation fresh.
- [x] `LocaleController` restore was fire-and-forget — RESOLVED 2026-10-29: `ensureRestored()` awaited in `main()` before `runApp()` (first frame carries the stored language). Device-verified 2026-10-30: gu toggle → force-stop → relaunch → welcome screen renders gu immediately.

### Launch/identity audit (2026-10-31 — `docs/AUDIT-launch-identity-flow.md`)

A read-only audit of the launch → identity flow. Triage of what is real, what was already fixed, and what needs a ruling:

- [x] FGS never stops at End Shift (audit §6, P0) — FIXED: `TrackingEngine._applyStop` now calls `service.stop()`, so the persistent "Tracking active" notification no longer outlives the shift (PRD-2 §3 + F-D5 step 4). Test: `test/tracking/tracking_engine_test.dart` (stop calls the service once; a second stop stays one).
- [x] `OfflineSyncService.attachTrip` had no production caller (audit §6, P0) — FIXED: the F-D2 auto-start seam attaches the session's trip before the permission flow, so a shift's catch-up Trail buffer drains on reconnect (F-D7 + §4 AC#4). Test: `test/features/shift_start/tracking_auto_start_test.dart`.
- [x] `complaints` rules had no `allow update` (audit §6, P0) — FIXED in `firestore.rules` and DEPLOYED to `safaaisaathi-63a87` on 2026-11-01 (`firebase deploy --only firestore:rules`), so D4's "Will Revisit" (status = assigned) and "Done" (status = resolved + resolvedAt) now write in production.
- [x] F-19 launch-time open-shift resume (the audit's "key ask") — RULED #27 and BUILT (2026-11-01): when the van still holds THIS driver's open shift, the welcome lookup reattaches it (read-only) and goes straight to D2 with tracking started, no tap; with no open shift the welcome card keeps its one tap. Another driver's shift and a failed read fall back to the card. PRD-2 §0.16 carries the ruling; tests: `identity_flow_test.dart` (resume/ownership) + `code_start_screen_test.dart` (direct vs one-tap).
- [ ] F-05 "Different driver?" does not clear the stored code — NOT A BUG: `resetToEntry` deliberately keeps the code ("only a new confirm overwrites it"), and the verified back-arrow seam depends on it.
- [x] F-06 welcome card shows Name/Code/Wards, not Van/Route — RULED #28 and BUILT (2026-11-01): five rows — Name, Code, Van plate, Route name, ward count. The route name is resolved at lookup time and falls back to the raw route id, never failing the lookup. PRD-2 §0.16 + DESIGN §9.27 updated.
- [x] F-07 "Different driver?" vs the design's "Change code" — CLOSED: the identity-review ruling (2026-10-31) chose "Different driver?"; the design file is the stale side.
- [x] F-08 shared-van conflict shows the generic "Check the connection" copy — RESOLVED by the contract copy (`02-contracts/errors.json`): `vanHeldByAnotherDriver`, `vanAlreadyClaimed` and `staleMarker` map to `identityShiftConflictOtherDriver` / `identityShiftConflictClaimed` / `identityShiftConflictStaleMarker` through `failureCopy` (PR #32). The issue closes when the adoption PR merges.
- [x] `offlineStatusProvider` returned an empty stream (audit §6, P2) — FIXED: the D2 offline badge was permanently hidden because the provider's default never flipped to the connectivity_plus detector the offline ticket shipped. It now maps `connectivitySourceProvider.status` (interface presence) to offline; the D2 pump harnesses pin it per test so no test reaches the platform channel.
- [x] vanId custom-claim rule check (audit §6) — CLOSED BY DESIGN: the §0.16 security stance says the 0.8 rules carry no custom-claim checks; the production wall is rules tightening + App Check.
- [x] Doc drift (F-14/F-15/F-16) — the runbook's "session restore → D2 relaunch" line is pre-identity and now false (corrected above); the dev-entrypoint list now includes `dev_flow_preview.dart` + `dev_identity_start.dart`.

### Improvement Bag
- [ ] Productionize build config per the "Production-grade config & security plan" (2026-10-29): Android flavors `dev`/`prod` + per-flavor gitignored `google-services.json` + apply the Gradle plugin + plain `initializeApp()`; App Check + Play Integrity on staging/prod; key restrictions (SHA-256 bind); CI secrets (JSONs + keystore) + AAB pipeline; kill `DEMO_SEED_BYPASS`. AFTER ticket 14 (restructures the Android build). *(me, after ticket 14)*
- [x] Locale flip `en` → `gu` before demo — DONE (issue #14, B1): the SHIPPING default is now Gujarati (`defaultAppLocale = Locale('gu')` in `core/l10n/locale_controller.dart`; MaterialApp fallback + toggle fallback read it). A stored choice wins in either direction; deviation pinned in `test/core/l10n/default_locale_test.dart`. 407/407 green.
- [x] `whereIn` >30-ward chunking (B-06, PR #39) — DONE: `readWardsByIds` deduplicates and splits ids into ordered chunks of 30, one query each. The pure helper is tested at 0/30/31/65 ids. Latent today because the live route uses `watchRouteWards`.
- [x] Platform contract 2.0.0 and 2.1.0 — ADOPTED. The record is `.contract/adopted.json` (truth) plus the platform report. Evidence PRs: #32 (2.0.0), #40 (CHG-0017 mock-location callable). Remaining audit fixes shipped separately: #33 (F-20/F-09), #34 (B-22 van topic leave), #35 (B-25 seed guard), #36 (B-04 notices chunks), #37 (F-11 app-wide session gate), #38 (B-21 inbound FCM), #39 (B-06/B-18 repository hygiene), #41 (F-17/F-18 docs).
- [ ] Delete dev entrypoints at integration: `dev_tracking.dart`, `dev_pending_reports.dart`, `dev_live_route.dart`, `dev_notices.dart`, `dev_min.dart`, `dev_flow_preview.dart`, `dev_identity_start.dart`. *(me → 14)*
- [ ] Index seeds for Backend Owner: notices OR-branch sort, pending-reports `(wardId, createdAt)`, trip `(vanId, date)` (rulings 10/11/16). *(Backend Owner)*
- [x] Real Firebase config: **delivered 2026-10-26** — Android app `1:179594621556:android:8bdac1de2d29745aad1721` registered on `safaaisaathi-63a87` via `flutterfire configure`; CLI logged in as the owner's Google account. Values reach the app at RUN TIME via dart-defines `DRIVERAPP_FB_API_KEY` / `_FB_APP_ID` / `_FB_SENDER_ID` (see `sharedProjectFirebaseOptions()`) — **no keys in the repo** (§0.10); generated files (`lib/firebase_options.dart`, `google-services.json`, `firebase.json`) are gitignored. Run with `--dart-define=DRIVERAPP_USE_EMULATOR=false` + the 3 value defines — since 2026-10-29 the values live in the gitignored **`.env`** and ride in via `--dart-define-from-file`; the committed `scripts/run_device.sh` wraps the whole thing (auto-rebuilds `.env` from the flutterfire file if it goes missing). Gradle `google-services` plugin deliberately NOT applied (fresh clones build without the private JSON). *(me)*
- [x] Integration: insert `MockLocationWarningBanner(vanId: vanId)` at top of D2's body `Column` (ticket 11 report §c) when D2 merges. *(me — at 06 merge)* — DONE at the 06 merge; covered by full-suite gates.
- [x] Day-window seam semantics (from ticket 10) — RESOLVED 2026-10-31 (issue #15): both reads now build their window in the WRITE frame (`istDayWindow`: `[utcStartOfIstDay(now), +24h)`), so the day no longer depends on the phone's timezone; the history cutoff is the next IST midnight (exclusive), so a trip dated exactly there belongs to the next day only. The fake repository mirrors the same frame (`isSameDayIST`), which is why the ticket-04 date-vs-date equality never showed the bug in tests. Complaints stay out of scope (`createdAt` is an event instant, not a day key). No contract change; 425/425 green.

### Feature Bag
- [ ] Notices read-state is session-local — the 0.2 `notices` shape has NO read field, so unread markers reset on restart/shift end (red test pins mark-read writes nothing). The contract now defines `noticeReceipt`, but no CHG entry exists, so the app does not write it yet. *(Backend Owner)*
- [ ] Staff push on mock-location detection — no contract Cloud Function exists (ruling 7). *(Backend Owner)*
- [x] Inbound notices push — B-21 (PR #38): the app parses the contract payload, routes a tap to the notices inbox (cold launch held until the session exists), and keeps the background handler a documented no-op because the inbox is the source of truth. The optional topic registry (B-23) is still open. *(me)*
- [x] Deploy real `verifyDriverPin` callable + seed vans docs — deployed 2026-10-29. **Superseded by CHG-0006:** the function is dead code, the app does not call it, and the backend sweep deletes it. The app signs in with the `bindDeviceToVan` custom token (CHG-0003). *(Backend Owner)*
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
- [x] **Prod-run command is load-bearing**: every prod `flutter run` MUST carry the full defines — `--dart-define=DRIVERAPP_USE_EMULATOR=false` plus the 3 value defines (`DRIVERAPP_FB_API_KEY` / `_FB_APP_ID=1:179594621556:android:8bdac1de2d29745aad1721` / `_FB_SENDER_ID=179594621556`; the API-key literal stays OUT of the repo per the no-keys ruling — as of 2026-10-29 the committed `scripts/run_device.sh` carries all of them automatically, see the Live-device runbook). Dropping the defines silently rebuilds with `kUseFirebaseEmulator` defaultValue:true → the app targets phone-localhost:9099/8080 (nothing there) → `auth/network-request-failed` forever, "Couldn't load vans"/"No vans found" (empty via the Firestore cache fallback). Symptom chain fully proven 2026-10-28. *(me)*
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

### Live-device runbook (2026-10-29 — the full setup that got the app live on M215F RZ8NA1CAS3T)

- **One command**: `./scripts/run_device.sh RZ8NA1CAS3T` — compiles the gitignored **`.env`** in via `--dart-define-from-file` (PRD-2 §0.10's own prescribed mechanism: ".env and google-services.json are shared privately"). Direct equivalent: `flutter run --dart-define-from-file=.env -d <id>`. The `.env` holds `DRIVERAPP_USE_EMULATOR=false` + the 3 real-project defines; `String.fromEnvironment` reads them unchanged, so the delivery method is invisible to the app. Script auto-regenerates `.env` from the flutterfire file if it goes missing; fresh clone = `flutterfire configure` once (template lives in the committed `.env.example`). A bare `flutter run -d <id>` still can never work while the keys stay uncommitted — nothing outside this machine knows them. Emulator mode stays manual (a key must not appear in BOTH a defines-file and --dart-define): `--dart-define=DRIVERAPP_USE_EMULATOR=true --dart-define=DRIVERAPP_EMULATOR_HOST=<dev-machine LAN IP>` — `localhost` on a device is the DEVICE, not the dev machine (the proven root cause of "no vans / auth network-request-failed", 2026-10-29).
- **Backend prerequisites** (verified live 2026-10-29, project `safaaisaathi-63a87`): `firebase deploy --only firestore:rules` after EVERY rules edit (the driver write scope incl. `currentTripId` must be in the RELEASED rules, not just the file); `verifyDriverPin` / `setDriverPin` callables deployed — check hits with `firebase functions:log --only verifyDriverPin`; anonymous-auth provider enabled; seeded docs `vans/van-01` (plate GJ-01-V-2201), `routes/route-01` "West Loop", `wards/ward-1..3`, `vanSecrets/*` (hash = sha256 of `pin|vanId`, rate-limit 5/10 min).
- **Boot verify (in order)**: no `bootstrap degraded` lines in the run log → `I/FirebaseApp … initializing all Firebase APIs` → D1 skeleton resolves into the van picker (or straight to D2 via session restore when the van is `on_shift` with a `currentTripId`) → D2 renders OSM tiles + ward circles + van marker → `tracking: cycle … flush OK (N)` lines every 10 s → `vans/van-01.lastLocation.updatedAt` is seconds old (check via Firestore REST or the Firebase MCP `firestore_get_document`).
- **Permission flow §4.19 on a fresh install**: location-while-in-use → background-location → notifications → battery-exception rationales, in that order; all four granted before the tracking engine starts. Battery denied ⇒ "Tracking is off … Retry" banner: grant it, then tap Retry — no relaunch needed.
- **Session restore** (SUPERSEDED 2026-10-31 by the identity flow — kept for the pre-identity record): a shift left `on_shift` (Hive, F-D7) re-enters D2 directly on relaunch. To re-walk D1 pick-van → PIN, End Shift first (released rules now allow `currentTripId = null`). Under the current flow there is NO Hive session→D2 path: splash routes on the `setupDone` flag → the start-shift page (welcome-back card for a returning driver), and resume is one tap on "Start my Shift".
- Never launch a second `flutter run` while one is live (session-kill law, 2026-10-28) — stop the first with `pkill -f "flutter_tools[.]snapshot"` (bracket trick) first.

### Production-grade config & security plan (recorded 2026-10-29 — how THIS setup scales to prod)

- **Mindset shift first**: the Firebase Android API key is an IDENTIFIER, not a secret — it ships in every APK and is extractable (`strings lib/*/libapp.so`) no matter how it is compiled in. What actually protects a prod app: (1) **Firestore rules** as the authorization boundary (red-team per Standing Protocol §5), (2) **App Check + Play Integrity** (rejects any client that isn't the real signed app — kills scripted key abuse), (3) **key restrictions** in Google Cloud Console (bind the Android key to the release cert's SHA-256 + package name). TRUE secrets are only the service-account JSON (Cloud Functions runtime only — already true here) and the signing keystore. `vanSecrets` (PIN hashes, Functions-only read) is already production-grade.
- **Three projects, not one shared demo**: `dev` (loose rules, resettable, App Check off) / `staging` (prod-identical rules, rehearsal on real phones, App Check on) / `prod` (tight, App Check enforced). This is what §0.10's "develop against the emulator so nobody breaks shared data" was protecting — a staging project does that AND behaves like prod (real FCM, real Play Integrity), which emulators cannot.
- **Android flavors kill the key problem**: `productFlavors { dev (applicationIdSuffix .dev) / prod }`, one `google-services.json` per flavor (`android/app/src/<flavor>/`), google-services Gradle plugin (today deliberately NOT applied) auto-picks the right one, Dart calls plain `Firebase.initializeApp()` — no options, no defines, no script. JSONs stay gitignored; CI injects them.
- **CI/CD holds the private things**: both flavor JSONs + release keystore stored as CI secrets (base64), written only during the build; pipeline = test → `flutter build appbundle --release --flavor prod` → signed AAB → Play Store. **Play App Signing** (Play holds the release key; guard only the upload key). Nobody builds prod releases from a laptop.
- **Admin panel (PRD-3)**: `NEXT_PUBLIC_*` vars ship in the JS bundle — treat like the APK key (restricted identifier, never a credential). Real admin credentials live server-side (API routes / Functions) only.
- **Mapping to this repo**: the `.env` + `scripts/run_device.sh` flow stays the DEV workflow unchanged. Before prod: kill `DEMO_SEED_BYPASS` in `setDriverPin` (Functions comments already flag it for the integration sweep); seed each project with its own data (`dev-trip-1`, demo PINs never enter prod). §0.10's secrets line stays valid — it governs service accounts + keystores; API keys become restricted-CI-injected configuration. Timing: flavors restructure the Android build → do AFTER the ticket-14 rehearsal.

### Standing protocol (recorded 2026-10-24)
0. **USER VERIFICATION FIRST (directive 2026-10-25): after a feature (or the whole app) finishes building, verify it AS A USER WOULD — open the running app, click through the feature, judge by what appears on screen. Green tests/analyze are necessary but NOT verification.** Loop: launch window (or device) → screenshot → interact (xdotool clicks/taps on-adapted for desktop; real finger on device) → screenshot → assert visible behavior. Dev entrypoints drive feature-level checks offline (Firebase has no desktop plugin — main() shows a bootstrap error on Linux); full user-loop runs on Android device at ticket 14.
1. Agent reports → gate (analyze + test in worktree) → merge → full-suite gate on main → **user verification of the merged feature (rule 0)** → rulings + glossary fold with bags updated.
2. Next frontier wave launches immediately (dependency table in `.scratch/driver-app/README.md`).
3. TDD from ticket 12 onward: failing tests first.
4. Ticket 14 (serial, last): integration rehearsal, real-phone stabilization, delete dev entrypoints.
5. Pentest after 14: auth/token abuse, Firestore rules red-team (foreign van/trip/complaint writes, `currentTripId`/`mockLocationDetected`), verifyDriverPin rate-limit/replay, input validation, mock-location adversary. Findings → Bug Bag, fixed on `feat/` branches.
6. Post-completion changes go through `feat/*` / `fix/*` branches only; no direct pushes to main.
7. **COMPACTION PROTOCOL (directive 2026-10-28): before and after every conversation compaction, use and update this GLOSSARY.md.** Before the context is summarized: fold the session's fresh domain terms, sharpened definitions, and fixed defects into Language + findings + bags (as they happen, not batched). After compaction: re-read this file FIRST to restore the domain context before continuing any work.
8. **REPO WRITE SCOPE (directive 2026-11-08): the agent may write code only in the driverapp repo. Every other repo (platform, userapp, adminpanel, and any other) is read only. The platform repo is remote only: treat it as absent from this machine, and read it with `gh`.** When a change is needed outside this repo, create a GitHub issue with four parts: the problem, the proposed change, the acceptance cases, and the files. Do not edit, commit, or push in those repos. The global rule lives in `~/.config/opencode/AGENTS.md`. The only override is an explicit instruction from the user in the current conversation. A past approval never carries over.
