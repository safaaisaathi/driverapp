# PRD 2 of 3: Driver App (Garbage Van)

**Goal:** Track each van's live location, log route completion and receive notices, with the least possible effort for the driver.
**Users:** Van drivers (often low-tech). One cheap Android phone per van mounted in the cab.

## 0. Shared Contract (IDENTICAL in all three PRDs, do not rename anything here)

**Project:** Citizen-Centric Garbage Collection and Sanitation Monitoring System (PS000051, DDO Panchmahal Godhra)
**Stack:** Flutter (user app, driver app), React/Next.js (admin panel), Firebase (Firestore, Storage, FCM, Anonymous Auth, Cloud Functions), OpenStreetMap with flutter_map / Leaflet.
**Languages:** `gu` (Gujarati), `en` (English). All user-facing strings go in localization files, never hardcoded.

### 0.1 Naming rules
- Collections: plural camelCase. Fields: camelCase. Enum values: snake_case. IDs: strings.
- Timestamps: Firestore Timestamp. Location: `{ lat: number, lng: number }`.
- Ticket ID format: `PMH-YYYYMMDD-NNNN`.
- Agent rule: do not add, rename or remove fields or enums without asking. If something is missing, ask first.

### 0.2 Collections
- `wards`: id, name, nameGu, code, type, center{lat,lng}, radiusM, routeId, inspectorId, escalationTo (staffId)
- `vans`: id, plateNo, routeId, status, lastLocation{lat,lng,updatedAt,speedKmph}, currentTripId, batteryPct
- `vanSecrets`: id (same as vanId), driverPinHash (never readable by apps, only by Cloud Functions)
- `routes`: id, name, wardIds[] (in visiting order), scheduledStartTime ("HH:mm")
- `trips`: id, vanId, routeId, date, startedAt, endedAt, wardsDone[{wardId,doneAt,flagged}], alertedWardIds[], gpsTrail[{lat,lng,t}], mockLocationDetected
- `complaints`: id, ticketId, deviceId, category, photoUrl, location, wardId, createdAt, status, assignedTo, escalationLevel, resolvedPhotoUrl, resolvedAt, mergedInto, note
- `ratings`: id, wardId, date, stars, deviceId
- `notices`: id, targetType, targetId, message, createdAt, createdBy
- `staff`: id, authUid, name, role, wardIds[], talukaId, phone

### 0.3 Enums
- `ward.type`: urban, rural
- `van.status`: idle, on_shift, offline
- `complaint.category`: garbage_dump, open_gutter, missed_collection, other
- `complaint.status`: received, assigned, resolved, escalated
- `complaint.escalationLevel`: 0 (inspector), 1 (chief officer or TDO via `wards.escalationTo`), 2 (DDO)
- `notice.targetType`: van, ward, all
- `staff.role`: inspector, chief_officer, tdo, ddo

### 0.4 Constants (one config file per project, same names)
GPS_INTERVAL_SEC=10, GPS_INTERVAL_LOW_BATTERY_SEC=30, LOW_BATTERY_PCT=20, OFFLINE_THRESHOLD_MIN=10, STALE_LOCATION_SEC=60, ARRIVAL_ALERT_RADIUS_M=500, DUPLICATE_RADIUS_M=50, MAX_COMPLAINTS_PER_DEVICE_PER_DAY=5, MISSED_REPORT_THRESHOLD=3, ESCALATION_L1_HOURS=24, ESCALATION_L2_HOURS=48, AVG_VAN_SPEED_KMPH=15, MIN_MOVE_M=15, HEARTBEAT_SEC=30

### 0.5 Design tokens (same names in Flutter theme and CSS variables)
- `color.primary` #1E8E5A, `color.onPrimary` #FFFFFF, `color.background` #F6F8F7, `color.surface` #FFFFFF, `color.textPrimary` #1B1F1D, `color.textMuted` #5F6B66
- Status colors: `color.statusReceived` #F2A100, `color.statusAssigned` #2F6FDE, `color.statusResolved` #1E8E5A, `color.statusEscalated` #D93025
- `radius.md` 12px, `spacing.unit` 8px, font: Noto Sans (supports Gujarati)
- (If a %code design DESIGN.md is made later, it replaces these values but keeps these token names.)

### 0.6 Live location flow (the core loop)
1. Driver app writes `vans/{vanId}.lastLocation` every GPS_INTERVAL_SEC while status is `on_shift`.
2. User app finds its `wardId` (device location inside a ward's `center` + `radiusM`, or manual pick) and saves it locally.
3. `wards.routeId` tells the user app which route serves it. It listens ONLY to vans where `routeId == ward.routeId` and `status == on_shift`. It never loads all vans.
4. ETA (prototype): sum of straight-line distances from the van through the remaining wards in `routes.wardIds` up to the user's ward, divided by AVG_VAN_SPEED_KMPH. If `lastLocation.updatedAt` is older than STALE_LOCATION_SEC, show "last seen X min ago".
5. Arrival alert: the Cloud Function `arrivalAlert` runs on every `vans/{vanId}` update. If the van is within ARRIVAL_ALERT_RADIUS_M of the next ward not in `trips.alertedWardIds`, it sends an FCM push to topic `ward_{wardId}` and adds that ward to `alertedWardIds`.
6. FCM topics: `ward_{wardId}` (user app subscribes after ward is known), `van_{vanId}` (driver app subscribes after shift start), `all` (both apps subscribe on first launch).

### 0.7 Cloud Functions (backend, shared by all three apps)
- `arrivalAlert`: on `vans` write, see 0.6.
- `mergeDuplicates`: on `complaints` create, if another open complaint has the same category within DUPLICATE_RADIUS_M, set `mergedInto` on the new one.
- `missedCollectionAlert`: on `complaints` create with category `missed_collection`, if MISSED_REPORT_THRESHOLD reports exist for the same ward today, push to the ward inspector (`staff_{inspectorId}`). It never dispatches vans automatically.
- `escalateComplaints`: scheduled every 15 min. Open complaints older than ESCALATION_L1_HOURS go to level 1, older than ESCALATION_L2_HOURS go to level 2. Set `status = escalated` and notify the new level.
- `vanOfflineWatch`: scheduled every 5 min. A van `on_shift` with no update for OFFLINE_THRESHOLD_MIN gets `status = offline` and an admin alert.
- `verifyDriverPin` (callable): input `vanId`, `pin`. Compares with `vanSecrets`, rate-limited to 5 tries per 10 minutes, returns a custom auth token with claim `vanId`.
- `setDriverPin` (callable, admin only): writes the hashed PIN to `vanSecrets`.
- `sendNotice`: on `notices` create, sends FCM to topic `all`, `ward_{targetId}` or `van_{targetId}` depending on `targetType`.

### 0.8 Security rules (summary)
- Anyone (anonymous auth) can create complaints and ratings, and read their own complaints by `deviceId`.
- Anyone can read `wards`, `routes`, and the `vans` fields needed for the map (`lastLocation`, `status`, `routeId`, `plateNo`).
- Only a driver session whose token has `vanId` equal to the document can write that van's `lastLocation`, `status`, `batteryPct` and its `trips`. A driver may also update `status` of `missed_collection` complaints in its route's wards.
- `vanSecrets` is not readable or writable from any app.
- Staff role and scope come from custom claims (`role`, `staffId`), set by the seed script.
- Only signed-in `staff` can update complaint status, assignments, notices and read all complaints.

### 0.9 Team and roles (TEAM TO CONFIRM: fill in names, edit if your split differs)
| Role | Owner | Builds |
|---|---|---|
| Backend and Integration Owner | [name] | Firebase project, Firestore rules, Cloud Functions (0.7), seed script, owns section 0, reviews and merges PRs, runs the end-to-end tests |
| User App Owner | [name] | PRD-1 (user app) |
| Driver App Owner | [name] | PRD-2 (driver app) |
| Admin Panel and Demo Owner | [name] | PRD-3 (admin panel), demo story, pitch slides |

If the team is smaller, one person takes several roles. The order of work (0.14) stays the same.

### 0.10 How the team works
- **Section 0 is the contract.** Only the Backend and Integration Owner changes it. Anyone who needs a change asks in the group chat; the change is then applied to all three PRDs in the same commit and announced.
- **One monorepo:**
  ```
  /apps/user_app   /apps/driver_app   /apps/admin_panel
  /backend/functions   /backend/firestore.rules   /backend/seed
  /docs/PRD-1-user-app.md  /docs/PRD-2-driver-app.md  /docs/PRD-3-admin-panel.md  /docs/DESIGN.md (added later)
  ```
- **Git:** `main` must always run. Branch per feature: `feat/<app>-<featureId>` (example `feat/driver-F-D2`). Small PRs, one feature each. Merge only after that feature's acceptance criteria pass. The Integration Owner reviews.
- **Environments:** one shared Firebase project for the demo, region `asia-south1` (Mumbai). Everyone develops against the Firebase Emulator Suite locally so nobody breaks shared data. Shared project is used only at integration checkpoints.
- **Integration checkpoints:** end of Phase 2 and Phase 4 (see 0.14). All owners run the end-to-end tests together on real phones.
- **Blocked?** Message the owner of the thing you depend on. Never work around it by renaming fields or changing the contract.
- **Secrets:** no keys in the repo. `.env` and `google-services.json` are shared privately.

### 0.11 Architecture rules (all builders)
- **Flutter apps:** feature-first folders `lib/features/<feature>/{data,domain,ui}` and `lib/core/{config,theme,l10n,models,repositories}`. State management: Riverpod.
- **Data access only through repositories** in `core/repositories`, one per collection (`VansRepository`, `ComplaintsRepository`, ...). Widgets never call Firebase directly.
- **Models** are plain classes with `fromMap`/`toMap` that mirror 0.2 exactly. Constants live in one config file with the exact names from 0.4.
- **Styling** comes only from the theme built from 0.5 tokens. No hardcoded colors, sizes or strings. All text goes through localization (`gu`, `en`).
- **Every screen** has loading, empty, error and offline states.
- **Admin panel:** Next.js (or Vite) React with TypeScript strict. `src/types` mirrors 0.2, `src/repositories` mirrors the Flutter repositories, styles from CSS variables built from 0.5.
- **Backend:** TypeScript Cloud Functions, one file per function with the exact names in 0.7, a `constants.ts` mirroring 0.4. Distance and ETA helpers get unit tests.
- **Listeners:** attach only while the screen is visible, always cancel on dispose. The user app never listens to a whole collection.
- **Photos:** compress under 500 KB. Storage paths: `complaints/{complaintId}/photo.jpg` and `complaints/{complaintId}/resolved.jpg`.
- **Ticket IDs:** generated by the client as `PMH-YYYYMMDD-` plus 4 random digits (prototype-level collision risk is accepted).
- **Privacy:** photos of public places may contain faces or number plates. Show a one-line notice on the report screen. Store data in `asia-south1`.

### 0.12 DESIGN.md (added later)
A `/docs/DESIGN.md` design-system file will be created later from a reference UI. When it exists: read it before building any UI, treat it as the source for colors, typography, spacing, components, page layouts and light/dark mode, and let it override the values in 0.5. The token names in 0.5 do not change, so no code breaks. Until then use 0.5, and keep every style in one theme file so swapping is a single change.

### 0.13 Location sharing: full specification (all three apps)
**Who does what**
| | Driver app | Backend | User app | Admin panel |
|---|---|---|---|---|
| Role | Writes the van's position | Verifies drivers, sends alerts, detects silent vans | Finds its ward's van and shows it | Watches all vans in the staff member's scope |
| Reads | own `vans` doc, `routes`, `wards` | `vans`, `trips`, `wards`, `routes` | `wards`, `routes`, `vans` of its own route only, today's `trips` | `vans`, `trips`, `complaints` |
| Writes | `vans.lastLocation`, `vans.status`, `vans.batteryPct`, `trips` | `trips.alertedWardIds`, `vans.status = offline` | nothing to location data | nothing (read-only) |

**Data shape (written by the driver app):** `vans/{vanId}.lastLocation = { lat, lng, updatedAt (server timestamp), speedKmph }`, plus `vans.batteryPct` and `vans.status`.

**Write policy:** check the position every GPS_INTERVAL_SEC (GPS_INTERVAL_LOW_BATTERY_SEC when battery is below LOW_BATTERY_PCT). Write to Firestore only if the van moved at least MIN_MOVE_M since the last written point, or HEARTBEAT_SEC has passed since the last write, so a stopped van never looks dead.

**Flow A: driver to storage**
1. Driver signs in with the PIN (`verifyDriverPin`), taps Start Shift. Trip doc created, `vans.status = on_shift`.
2. A foreground service reads GPS and applies the write policy.
3. Each write updates `vans/{vanId}.lastLocation` (one small document, overwritten).
4. Every 30 seconds the buffered points are appended to `trips.gpsTrail` in one batch.
5. End Shift stops the service and sets `vans.status = idle`.

**Flow B: user finds the right van**
1. User app resolves `wardId` from the phone's location (nearest ward whose `center` is within `radiusM`) or the manual picker. Saved locally.
2. `wards.routeId` gives the route. The user app queries only `vans` where `routeId == that route` and `status == on_shift`.
3. If two vans are on one route, show both; ETA is for the one that has not yet passed the user's ward.
4. If no van is on shift: show "No van on route right now" and `routes.scheduledStartTime`.

**Flow C: ETA (prototype method)**
Remaining stops = wards in `routes.wardIds` order starting from the first ward not in today's `trips.wardsDone`, up to the user's ward. Distance = van position to the first remaining ward center, then ward center to ward center, up to the user's ward (straight-line, haversine). ETA minutes = distance km / speed km/h x 60, using `lastLocation.speedKmph` if it is above 5, otherwise AVG_VAN_SPEED_KMPH. If the user's ward is already in `wardsDone`, show "Collected today at HH:mm". If `updatedAt` is older than STALE_LOCATION_SEC show "Last seen X min ago".

**Flow D: arrival alert**
`arrivalAlert` runs on every `vans/{vanId}` update. It finds the next ward not in `trips.wardsDone`. If the van is within ARRIVAL_ALERT_RADIUS_M of that ward's center and the ward is not in `trips.alertedWardIds`, it sends an FCM push to topic `ward_{wardId}` and adds the ward to `alertedWardIds`. Users never poll for this.

**Flow E: admin view**
Admin panel listens to `vans` limited to its staff scope (routes of its wards). A3 Live Map shows markers, colored by `van.status`; a van with `offline` status or stale `updatedAt` gets an offline badge. Trip replay (optional) reads `trips.gpsTrail`.

**Flow F: silent van**
`vanOfflineWatch` marks a van `offline` after OFFLINE_THRESHOLD_MIN without updates and alerts the admin. When the van writes again, the driver app sets `status = on_shift`.

**Edge cases to handle**
Driver loses network (buffer trail, Firestore queues the latest write); phone restarted mid-shift (resume from `vans.currentTripId`); user outside every ward (picker); overlapping ward circles (nearest center wins); van finishes the route (status `idle`, hidden from user app); permissions denied (clear message, no crash).

**Cost and scale note (known risk)**
At a 10-second check with the write policy above, one van writes at most about 2,900 times per 8-hour shift. Firestore's free quota is 20,000 writes per day, which covers about 6 vans. Reads multiply by watchers: 100 people watching one van can cause about 290,000 reads per day, far above the free 50,000. This is fine for a demo and a small pilot. For real scale, move only the live location path to Firebase Realtime Database (billed by bandwidth), or raise MIN_MOVE_M and HEARTBEAT_SEC. Tell the Integration Owner before changing it; the contract names stay the same.

**Test L1 (end-to-end, must pass at Checkpoint 1)**
Driver phone starts a shift on route R, a second phone with the user app in a ward of R shows the van moving within 15 seconds, a third phone with a user in a ward of a different route shows no van, and the admin Live Map shows the same van.

### 0.14 Steps to complete the project (in this order)
- **Phase 0, Setup (everyone):** repo, Firebase project, emulators, config files, theme from 0.5, seed data (wards, routes, vans, staff). Done when every app boots and reads `wards` from the emulator.
- **Phase 1, Location loop:** Driver F-D1, F-D2; User F-U1; Backend `verifyDriverPin`, rules for `vans`. Done when Test L1 passes.
- **Phase 2, Complaints loop:** User F-U2, F-U3; Admin F-A1, F-A4 (basic); Backend `mergeDuplicates`, rules for `complaints`. **Checkpoint 1 / Test C1:** a complaint from the user phone appears in the admin table with photo and location within 10 seconds, and the user sees its status change after the admin assigns it.
- **Phase 3, Operations:** Driver F-D3, F-D5; Admin F-A2, F-A3; User F-U6, F-U8; Backend `arrivalAlert`, `vanOfflineWatch`.
- **Phase 4, Alerts and escalation:** User F-U4 button; Driver F-D4; Admin F-A5, F-A6; Backend `missedCollectionAlert`, `escalateComplaints`, `sendNotice`. **Checkpoint 2 / Test E1:** with test time shortened, an old complaint escalates to level 1 and the officer sees it; three missed-collection reports in one ward alert the inspector.
- **Phase 5, Optional features** in this priority: ratings (F-U7), driver Pending Reports (F-D6), ward performance (F-A7), heatmap (F-A8), vans and routes CRUD (F-A9), offline polish (F-D7), trip replay (F-A10).
- **Phase 6, Freeze and polish:** apply DESIGN.md, test on real phones, run the seed script for demo data, add the simulated van, record a backup screen video, finalize the pitch.

### 0.15 Rules for the coding agent
1. Read all of section 0 first, then only your own file's sections.
2. Optionally run `/grill-me` on this file before building, to find gaps.
3. Build one feature at a time, in the order of 0.14. After each feature, run its acceptance criteria, then commit.
4. Never rename or add collections, fields, enums, constants or tokens. If something is missing, stop and ask.
5. Do not build anything listed under "Out of scope".
6. Use DESIGN.md as soon as it exists (0.12).
7. When a feature touches another app's work (for example the driver writes what the user reads), follow the exact shapes in 0.2 and 0.13.

### 0.16 Driver identity and onboarding (added 2026-10-30, replaces the D1 PIN flow)

Decision source: grill session 2026-10-30 + spec (GitHub issue #1, safaaisaathi/driverapp). Supersedes the D1 half of `F-D1` (van picker + PIN) and the driver-app side of the `verifyDriverPin` callable (0.7). The Function stays deployed until the backend sweep deletes it; the app simply stops calling it.

- **`drivers` collection (new; 0.2 addition).** Doc ID = the normalized driver code `AB-1234`: two uppercase letters, dash, four digits (regex `^[A-Z]{2}-[0-9]{4}$`). Fields: `name` (string), `phone` (string), `vanId` (string), `routeId` (string), `wardIds` (array of ward ids, one or more), `active` (bool). Writes are admin-only (Firestore console now, PRD-3 panel later); the app only reads.
- **Code normalization.** Input `ab1234` / `AB-1234` / `ab-1234` → trim, uppercase, insert dash → `AB-1234`. A bad shape never reaches Firestore.
- **Launch flow.** Splash (no buttons, no mascot, auto-advances when bootstrap is ready) → the device-local `setupDone` flag decides: fresh device → Welcome → the 4-stage permission setup (0.13 order: `locationWhileInUse` → `locationBackground` → `notifications` → `batteryOptimization`) → `setupDone = true` → start-shift page; returning device → start-shift page directly. The Start Duty interstitial is deleted.
- **Start-shift page.** Code entry → signed-in read of `drivers/{CODE}` → confirm card (driver name, allotted van, COUNT of `wardIds`, phone masked `98XXXXXX10`) → Start Shift. Distinct not-found and offline states, both with retry. After the first confirm the code is remembered on-device; the next launch shows a Welcome-back card with a change-code option beside it. The code field flips the phone keyboard with the input: text keyboard for the letter half, numeric keypad for the digit half; the dash is auto-inserted after the 2nd letter (the numeric keypad has no dash key) and deleting back below the dash re-flips. The setup's permission screens carry the app's existing language toggle (the shared `LanguageToggleButton`, top-end), so the driver can switch to Gujarati at any point of the setup.
- **Trip contract additions.** `trips.driverId` (string = the confirmed code) and `trips.wardIds` (array = the driver's allotted wards; D2 scopes map + ward marking to it). The van comes from `drivers.vanId` (van picker deleted). `vans.currentTripId`, `status: on_shift`, `routeId` handling unchanged.
- **D2 scoping (rulings from the ticket-7 review, 2026-10-30).** Scope is the SET from the trip: a 0.16 trip (non-empty `driverId`) renders exactly its `wardIds` - an empty array renders an empty map + list, never the whole route. ORDER is always the route's visiting order: D2 renders `routes.wardIds` filtered to the trip's set, so a driver's allotment never reorders the visit sequence (F-D3.1). A trip without a `driverId` (pre-0.16) falls back to the whole route.
- **Resume (ruling from the ticket-7 review, 2026-10-30).** Vans can be shared between drivers (seed AB-1001 and AB-1002 both sit on van-01), so a resume is allowed only when the open trip belongs to the confirmed driver: `trips.driverId` non-empty and different -> Start fails with the inline retryable error; the trip is never taken over and never rewritten. A trip without a `driverId` (pre-0.16) resumes with the route fallback.
- **Returning-device surface (ruling from the identity review, 2026-10-31).** A device that remembers the code shows the welcome-back card and nothing else: the code boxes NEVER render for a returning driver, in any phase, including every failure. A failure renders INSIDE the card (title + body in the shared error tint) with the pinned CTA = Retry; `Different driver?` stays visible and is the only route to the entry form. A device that never came through that link has no back arrow and keeps the default back. The fresh-device flow is unchanged: Welcome -> permission setup -> code entry -> confirm card -> Start Shift.
- **Launch-time resume (ruling #27, 2026-11-01).** A returning device whose van still holds THIS driver's open shift (`vans.status = on_shift` + `currentTripId` set, `trips.driverId` matching the code) resumes WITHOUT a tap: the welcome lookup reattaches the existing trip and goes straight to D2 with tracking started. With no open shift the welcome-back card keeps its one-tap `Start my Shift`. The reattach is read-only (no trip created, no trip rewritten); another driver's open shift and a failed read fall back to the card.
- **Welcome card content (ruling #28, 2026-11-01).** The card shows five rows: Name, Code, Van (plate), Route (name), and the allotted ward count. Van plate and route name are resolved at lookup time; a missing or unreadable route doc falls back to the raw route id and never fails the lookup.
- **First-read auth gate (issues #18/#21, 2026-10-31).** The start-shift lookup waits for the anonymous session (8 s cap) before its first Firestore read: the read used to race `main()`'s fire-and-forget boot, fail unauthenticated on EVERY cold launch, and silently render as the offline state. Failure phases keep the confirm data (`copyWith`), so a failed retry keeps the driver's name on the card.
- **Post-search edit (2026-10-31).** After a search the boxes drop focus and the result action owns the pinned CTA (Start Shift / Retry); tapping the boxes re-enters editing, hides the result card and returns the search CTA. A searched-but-wrong code is corrected this way instead of only being retried.
- **Security stance.** The code is a badge number, NOT a secret: no OTP, no PIN. The app keeps its anonymous auth session (the PIN callable's custom-token sign-in is not load-bearing; 0.8 rules carry no custom-claim checks). The production wall is rules tightening + App Check per the production plan (GLOSSARY 2026-10-29).
- **Rules.** `match /drivers/{code} { allow read: if request.auth != null; }` and nothing else.
- **Screens.** `D1 Shift Start` becomes the driver-code entry + confirm card; splash/welcome per above; the Start Duty screen is deleted.

---

## 1. Features
**Core (must demo)**
- `F-D1` PIN login, choose van, start shift (route comes from the van's `routeId`)
- `F-D2` Background GPS every GPS_INTERVAL_SEC writing `vans.lastLocation`
- `F-D3` Route ward list with "Mark ward done"
- `F-D4` Notices inbox (push via topic `van_{vanId}`)
- `F-D5` End shift and save trip log

**Optional**
- `F-D6` Pending Reports list (missed-collection complaints for today's wards)
- `F-D7` Offline GPS buffer and sync
- `F-D8` Low-battery interval fallback
- `F-D9` Mock-location detection and flagging
- `F-D10` Gujarati/English toggle

## 2. Screens (exact titles)
- `D1 Shift Start`: 4-digit PIN, van picker (assigned route is shown, admin changes it in A6), "Start Shift".
- `D2 Live Route`: full-screen map with the van and ward markers, ordered ward list (done wards ticked), large "Mark Ward Done" button for the next ward.
- `D3 Notices`: messages from admin (`notices` where target is this van, its ward, or all).
- `D4 Pending Reports`: today's `missed_collection` complaints for this route's wards, each with "Will Revisit" and "Done".
- `D5 End Shift`: summary (wards done, duration), confirm.

## 3. Behaviour rules
- **Shift start:** verify PIN with the callable `verifyDriverPin` and sign in with the returned token; create a `trips` doc; set `vans.status = on_shift` and `vans.currentTripId`; subscribe to `van_{vanId}`; start the background location service with a persistent notification.
- **GPS writes (follow 0.13 exactly):** update `vans.lastLocation` every GPS_INTERVAL_SEC. If battery is below LOW_BATTERY_PCT, use GPS_INTERVAL_LOW_BATTERY_SEC. Also save `batteryPct`. Append to `trips.gpsTrail` in batches (every 30 seconds), not on every ping.
- **Offline:** keep unsent points in a local queue and sync in order when online.
- **Mark Ward Done:** append `{wardId, doneAt}` to `trips.wardsDone`. If the van is outside that ward's `radiusM`, still allow it but set `flagged = true` on that `wardsDone` entry for admin review.
- **Pending Reports:** "Will Revisit" sets complaint `status = assigned`; "Done" sets `status = resolved` and `resolvedAt`.
- **End shift:** stop GPS, set `trips.endedAt`, `vans.status = idle`, `vans.currentTripId = null`.
- **Mock location:** if Android reports mock location, set `trips.mockLocationDetected = true` and notify admin.

## 4. Acceptance criteria
1. After "Start Shift", the user app shows the van within 15 seconds.
2. Ward done ticks appear on the user app's U1 Home for that ward.
3. Killing and reopening the app during a shift resumes tracking.
4. Switching network off for 2 minutes loses no GPS points after reconnect.
5. A notice sent from the admin panel arrives as a push within 10 seconds.

## 5. How to build each feature (follow in this order)
**F-D1 Shift start**
1. Scaffold per 0.11. Load the van list from public `vans` (id, plateNo).
2. D1: PIN, then call `verifyDriverPin(vanId, pin)` and `signInWithCustomToken`. Wrong PIN shows a friendly message; the function locks out after 5 tries.
3. Start Shift: create the `trips` doc (`vanId`, `routeId` from the van, `date`, `startedAt`), set `vans.status = on_shift` and `currentTripId`, subscribe to `van_{vanId}` and `all`.

**F-D2 Background GPS (the most important feature)**
1. Ask permissions in this order: location while in use, then background location, then notifications, then the battery-optimization exemption (explain why).
2. Run a foreground service with a persistent notification "Tracking active".
3. Use a location stream with `distanceFilter = MIN_MOVE_M`. Write `vans.lastLocation` following the write policy in 0.13. Use GPS_INTERVAL_LOW_BATTERY_SEC below LOW_BATTERY_PCT.
4. Buffer trail points locally and flush to `trips.gpsTrail` every 30 seconds and at End Shift.
5. If the app restarts and `vans.currentTripId` exists with `status = on_shift`, resume tracking without asking for the PIN again.

**F-D3 Mark ward done**
1. D2 shows `routes.wardIds` in order with names; the next ward is highlighted.
2. Tapping "Mark Ward Done" checks the distance to the ward `center` against `radiusM`, appends `{wardId, doneAt, flagged}` to `trips.wardsDone`, and activates the next ward.

**F-D4 Notices:** stream `notices` where `targetType == all`, or `van` with `targetId == vanId`, or `ward` with `targetId` in the route's wards. FCM push plus an unread badge.
**F-D5 End shift:** flush the trail, set `trips.endedAt`, `vans.status = idle`, `currentTripId = null`, stop the service.
**F-D6 Pending reports:** complaints for the route's wards, `category == missed_collection`, created today, status `received` or `assigned`.
**F-D7 Offline:** Firestore persistence on; trail kept in local storage; flushed in order on reconnect. Only the latest `lastLocation` matters.
**F-D9 Mock location:** if `Position.isMocked` is true, set `trips.mockLocationDetected = true`.

## 6. Requirements from the Driver App Owner
- Android only (iOS background tracking is out of scope).
- Packages: firebase_core, firebase_auth, cloud_firestore, firebase_messaging, flutter_riverpod, flutter_map, latlong2, geolocator, flutter_foreground_task (or flutter_background_service), battery_plus, hive.
- Buttons at least 56 dp, minimal text, simple one-hand layout.
- Test on a real phone: 60 minutes with screen off, screen locked, battery saver on, and airplane mode for 2 minutes.
- Needs from others: Backend Owner deploys `verifyDriverPin` and seeds `vanSecrets`, `wards`, `routes`.
- Gives to others: `lastLocation`, `trips`, complaint status updates in the exact shapes of 0.2 and 0.13.
- Done when: section 4 passes on a real phone.

## 7. Common vs only for this app
- **Common (section 0, do not change):** collections, enums, constants, tokens, location flow 0.13, Cloud Functions, rules, architecture, team workflow, DESIGN.md.
- **Only this app:** screens D1 to D5, foreground service, PIN sign-in, local trail buffer, mock-location check.

## 8. Out of scope
Turn-by-turn navigation, route optimization, payroll.
