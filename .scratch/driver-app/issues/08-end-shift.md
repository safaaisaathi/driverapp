# 08: F-D5 End Shift (D5)

**What to build:** "End Shift" from D2 opens D5: a simple summary (wards done count, shift duration), confirm stops everything — flush the trail buffer, set `trips.endedAt`, `vans.status = idle`, `vans.currentTripId = null`, stop the foreground service, unsubscribe driver topic handling cleanly. After end shift the app returns a neutral non-tracking state; the user app stops seeing the van (status idle hides it, contract Flow B.4/B edge). Cancellation keeps the shift running (decorator-safe: nothing written on cancel).

**Blocked by:** 05 (engine/flush points), 06 (button host), 07 (meaningful ward-done count for the summary).

**Status:** ready-for-agent

- [ ] Confirm: trail flushed in order, `endedAt` set, `status = idle`, `currentTripId = null`, service stopped — wrapped so all-or-nothing surfaces an error state on failure
- [ ] Cancel/discard leaves the trip and tracking exactly as before
- [ ] Summary shows wards done + duration (Today-based), localized
- [ ] Restarting a shift after end creates a new trip (04's resume branch must not trigger again)
- [ ] Widget tests via fake repositories (seam 1): confirm path writes all five effects, cancel writes none
