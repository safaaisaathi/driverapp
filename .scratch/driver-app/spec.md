# Spec: Driver App (Garbage Van) — PRD-2

Source: `docs/PRD-2-driver-app.md` (section 0 is the shared contract; this spec adds only driver-app decisions). Glossary vocabulary per `GLOSSARY.md`.

## Problem Statement

Van drivers currently have no way to signal where their van is or how far a route has progressed. Sanitation monitors cannot see vans on a map, wards cannot be told the van is arriving, and route completion is not recorded anywhere — the DDO office has no record of whether a van actually served its wards today.

Drivers are low-tech, hold the phone in a cab mount, and often work with gloves on, one hand, in sunlight. Any solution must demand almost nothing from them: sign in once, tap two big buttons ("Start Shift", "Mark Ward Done", "End Shift"), and let the phone do everything else automatically. It must also survive the realities of the job: background location tracking that keeps running with the screen off, no network for stretches, cheap phones with dying batteries, and occasionally drivers faking their position.

## Solution

One cheap Android phone per van runs a Flutter driver app. The driver picks their van and enters a 4-digit PIN. Tapping "Start Shift" sets the van live: a foreground service begins streaming GPS and writing the van's position to the shared backend every 10 seconds (30 s on low battery), only when the van has actually moved (or on a heartbeat), so the user app and admin panel can show the van moving on a live map. The driver's main screen is a full-screen map showing the route's wards in visiting order with a large "Mark Ward Done" button for the next ward. Admin notices arrive as push messages. When the shift ends, the app saves the trip log — trail, wards done, duration — and takes itself offline. Optional extras: pending missed-collection reports to triage with two taps ("Will Revisit" / "Done"), full offline buffering with guaranteed sync, mock-location detection, and a language toggle.

## User Stories

1. As a driver, I want to pick my van from a list, so that the app knows which vehicle's position to publish.
2. As a driver, I want to sign in with a 4-digit PIN instead of a password or email, so that sign-in takes one hand and seconds.
3. As a driver, I want a clear message when my PIN is wrong, so that I know to try again or ask the office (the backend locks out brute-force attempts).
4. As a driver, I want my assigned route shown on the van-picker screen, so that I can confirm I'm in the right van before starting.
5. As a driver, I want to tap one large "Start Shift" button, so that everything behind it (trip record, status, tracking) happens automatically.
6. As a driver, I want tracking to resume by itself if the phone restarts while I'm on shift, so that a crash or reboot midway doesn't end my day with magic PIN prompts.
7. As a driver (the office, really), I want a stuck van to offer "Resume shift" if the trip is still open, so that a restarted phone doesn't create a second, duplicate trip record.
8. As a driver, I want the app to publish my van's position automatically in the background, so that residents and admins see the van moving without me doing anything.
9. As a driver, I want the app to ask for permissions in a sensible order with simple explanations, so that even a first-timer can grant location, background location, notifications, and the battery-optimization exemption.
10. As a driver, I want a persistent "Tracking active" notification while my shift runs, so that I know tracking is running and Android doesn't kill it.
11. As a driver, I want the app to slow its GPS writes when battery is low, so that tracking survives the whole shift on a cheap phone.
12. As a driver, I want a full-screen map showing my route's wards in visiting order with done wards ticked, so that I always know where I am and what's next.
13. As a driver, I want one large "Mark Ward Done" button for the next ward, so that logging progress is a single tap.
14. As a driver, I want to mark a ward done even if I'm slightly out of the ward's circle or slightly out of visiting order, so that real-world routes (gates shut, skips, detours) don't block me — with such entries kept flagged for admin review.
15. As a driver, I want notices from the office delivered as push messages with an unread badge, so that I learn about route or timing changes without opening the app.
16. As a driver, I want an inbox listing notices addressed to my van, my route's wards, or everyone, so that I can look back at what the office told me.
17. As a driver, I want "End Shift" to give me a simple summary (wards done, duration) and one confirm tap, so that closing the day is deliberate and easy.
18. As a driver, I want my unsent location points kept on the phone when there's no network and synced in order when it returns, so that a dead zone in the route doesn't lose my trip history.
19. As a driver, I want today's missed-collection reports for my route's wards in one list, so that I know who is still waiting for me today.
20. As a driver, I want two buttons on each pending report — "Will Revisit" and "Done" — so that closing complaints takes two taps and no typing.
21. As a driver, I want the app to flag itself when my position is coming from a mock/fake GPS provider, so that honest drivers aren't grouped with cheaters and the office can see it.
22. As a driver, I want to switch between Gujarati and English on the first screen, so that the language matches what I actually read.
23. As a driver, I want big buttons (56 dp+), minimal text, and a one-hand layout, so that I can drive and tap without squinting.
24. As a demo driver (pilot user), I want the app to be boring and predictable — loading, empty, error and offline states on every screen — so that nothing adapts to surprises in a live demo.
25. As the DDO office, I want each driver shift logged as a trip record (trail, wards done, duration, flags), so that route completion is auditable after the fact.

## Implementation Decisions

All contract rules from PRD-2 section 0 apply unchanged (collections, fields, enums, constants, tokens, location flow 0.13, architecture 0.11). Decisions settled during the grilling session, plus here-noted technical choices:

- **Standalone repo.** This repository is the driver app only (not the contract's monorepo). The contract's feature-first layout (`features/<feature>/{data,domain,ui}`, `core/{config,theme,l10n,models,repositories}`) applies within this repo; the app is relocatable into `apps/driver_app` later if the monorepo ever materialises.
- **Anonymous auth at launch.** The van list must be readable before any PIN is entered, and the rules require a signed-in request. The app signs in anonymously on launch and upgrades to the custom token from `verifyDriverPin` at shift start. No contract fields change.
- **Resume, never duplicate trips (grilled decision).** If `vans.currentTripId` is set and `status == on_shift` when the driver taps Start, the app shows "Resume shift" and reattaches to the existing trip instead of creating a second one. The restart-resume rule (no re-PIN while `on_shift`) falls out of the same check.
- **Marking out of route order is allowed (grilled decision).** Only the next-in-order ward gets the dedicated large button; any other undone ward can be marked through a smaller control. Distance check and `flagged` semantics are identical to the contract either way. This keeps the Flow C "first ward not in `wardsDone`" model valid.
- **English default during development (grilled decision).** The locale is pinned to `en` with a Javadoc-visible TODO to remove before the demo; Gujarati translations ship from day one. Android launcher name is localized (`values` / `values-gu`).
- **"Today" resolves in Asia/Kolkata (grilled decision).** `trips.date` and all "created today" queries (Pending Reports, missed threshold) compute the calendar date at 00:00 IST on the device, independent of clock/timezone settings.
- **F-D8 folded into the tracking engine.** The low-battery interval fallback is not a separate feature; the engine reads battery percentage every check and switches the interval per the Write Policy.
- **App identity.** Package `com.sfic.driverapp`, Android-only (iOS background tracking out of scope). Foreground service via `flutter_foreground_task`; local trail buffer via Hive; state via Riverpod; requests only through repositories.
- **Mock-location admin notification.** The driver app sets `trips.mockLocationDetected = true` (contract shape) and shows a warning to the driver. Push-notification to staff would need a backend watcher on `trips`, which is not among the contract's Cloud Functions — referred to the Backend and Integration Owner rather than solved locally.
- **External dependencies.**
The Backend Owner must deploy `verifyDriverPin` / `setDriverPin`, seed `vanSecrets` + `wards` + `routes`, and publish Firestore rules for the driver's write scope (section 0.8). Shift-start and pending-report tickets are acceptanced against the emulator with seeded data.
- **Git flow per 0.10:** branch per feature `feat/driver-<slug>`, small PRs, merge after acceptance criteria pass.

## Testing Decisions

- **Good test:** tests external behaviour at the agreed seams, not widget internals or Firestore wiring. A failing test means broken behaviour, not refactored internals.
- **Seam 1 — Repository boundary (Riverpod).** The contract already isolates all Firebase access behind `core/repositories`; feature tests override repositories with fakes. Every screen (D1–D5) tests through this seam: signed in, PIN wrong, resume prompt, notice lists, pending-report actions, end-shift summary.
- **Seam 2 — Pure domain functions.** Unit tests without any Firebase, state or mocking: the **Write Policy** (`minMoveM` movement OR `heartbeatSec` stay), haversine distance vs `radiusM` (flagged / not), **Today** (IST resolution across midnight and edge cases), ward-order helpers (next ward, out-of-order lists).
- **Seam 3 — Firebase Emulator + real phone.** Reserved for the integration/rehearsal ticket (Test L1 client-side, 60-minute background battery run, 2-minute airplane-mode sync check). Never used per feature.
- **Prior art:** the Phase-0 smoke test (Phase 0 commit) is the only widget test in the repo; repository-based faking pattern starts here with the first verified ticket.

## Out of Scope

- Turn-by-turn navigation, route optimization, payroll (contract section 8).
- iOS background tracking (contract section 6).
- Anything in other apps' PRDs (user app screens, admin panel screens) — the driver app only writes the shapes they read (0.2, 0.13).
- Backend Cloud Functions, Firestore rules, seed data — owned by the Backend and Integration Owner.
- Backend notification push for mock-location, trip replay, ratings — backend / other PRD concerns.
- Applying `docs/DESIGN.md` — Phase 6; token names must not change until then.

## Further Notes

- Section 0.15 rules for the coding agent apply to every implementer of this spec: build one feature at a time in the 0.14 order; never rename or add collections, fields, enums, constants or tokens; stop and ask if something is missing; nothing from "Out of scope".
- The contract names the write-policy parameters exactly (`GPS_INTERVAL_SEC`, `MIN_MOVE_M`, `HEARTBEAT_SEC`, …); they live in one config file for the whole app.
- ADRs are pending for two grilled decisions (resume-vs-duplicate-trip; out-of-order ward marking); write them if the owner approves — both are recorded in Implementation Decisions meanwhile.
- Tickets live in the issue files next to this spec under `.scratch/driver-app/issues/`; migrate to GitHub Issues when a remote is added (`docs/agents/issue-tracker.md` describes the target tracker).
