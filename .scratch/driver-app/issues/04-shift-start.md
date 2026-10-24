# 04: F-D1 Shift Start (D1)

**What to build:** Driver picks their van (public `vans` doc: id, plateNo, assigned route name), enters the 4-digit PIN, taps "Start Shift". PIN verified via the callable `verifyDriverPin` and the returned custom token signed in (wrong PIN → friendly message; 5-try lockout surfaces clearly). Start Shift creates the `trips` doc (`vanId`, `routeId` from the van, `date` as Today, `startedAt`), sets `vans.status = on_shift` and `vans.currentTripId`, subscribes to topic `van_{vanId}`. Grilled decision: if `currentTripId` is already set and `status == on_shift`, the button becomes **"Resume shift"** and reattaches to the existing trip instead of creating a duplicate. Buttons ≥56 dp, minimal text.

**Blocked by:** 01 (models & repositories), 02 (Firebase bootstrap & anonymous session).

**Status:** ready-for-agent

- [ ] Wrong PIN shows friendly localized message; does not crash on multiple retries (rate-limit response handled)
- [ ] Correct PIN signs in with custom token and lands on-screen ready to Start; van's route name visible on D1
- [ ] Start (fresh) creates trip doc with exact 0.2 shape (vanId, routeId, date, startedAt) and sets `vans.status = on_shift`, `vans.currentTripId`
- [ ] Start with an already-active trip offers Resume, reattaches, creates no duplicate trip
- [ ] Verifiable against the emulator with seeded vans (requires Backend's `verifyDriverPin` + seed — noted dependency)
- [ ] Widget tests via fake repositories (seam 1): van list loading/empty/error states, both PIN outcomes, resume branch
