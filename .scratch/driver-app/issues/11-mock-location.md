# 11: F-D9 Mock-location detection

**What to build:** When the Android position provider reports a mocked fix (geolocator `isMocked`), the tracking engine sets `trips.mockLocationDetected = true` (exact contract field) and the app shows the driver a clear in-app warning banner with a localized wording that the office will see this. The flag latches for the trip (once true, stays true). Notifying staff by push is backend work (no contract function exists) — noted outward, not built here.

**Blocked by:** 05 (engine position stream), 01 (trips model).

**Status:** ready-for-agent

- [ ] Mock fix flips `trips.mockLocationDetected = true` on the open trip and cannot be unset by the app for that trip
- [ ] Real-fix (non-mocked) runs never set the field
- [ ] Driver sees a localized warning banner when detection has latched; normal UX otherwise
- [ ] Engine test (seam 2) on the mock/real decision hook; widget test for the banner state
