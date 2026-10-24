# 05: F-D2 Tracking engine + F-D8 low-battery fallback

**What to build:** The foreground location service that publishes the van's position. Permission flow in contract order (in-use location → background location → notifications → battery-optimization exemption, each explained simply; denials handled with a clear message, never a crash). Foreground service with persistent "Tracking active" notification. Geolocator stream with `distanceFilter = minMoveM`; every fix flows through the **Write Policy** (03) to update `vans/{vanId}.lastLocation` (`{lat,lng,updatedAt,speedKmph}`) plus `batteryPct`; low battery below `lowBatteryPct` switches to `gpsIntervalLowBatterySec` (F-D8 folded here). Trail points buffered locally and flushed to `trips.gpsTrail` in one batch every 30 seconds. Restart-resume: if `currentTripId` exists with `status = on_shift`, tracking restarts without asking for the PIN again. Exposes start(tripId, vanId)/stop so screens and End Shift can drive it; includes a debug entrypoint to demo tracking without D1 (removed at integration).

**Blocked by:** 01 (models & repositories), 02 (Firebase bootstrap), 03 (Write Policy).

**Status:** ready-for-agent

- [ ] Permissions requested in contract order; each denial gives a localized clear state and no crash
- [ ] Service survives screen off / app swipe-away within Android foreground-service norms; persistent notification visible
- [ ] On emulator/seeded run: `vans.lastLocation` updates obey Write Policy — no write for < minMoveM movement within heartbeat window; heartbeat write present; battery < lowBatteryPct widens interval
- [ ] `trips.gpsTrail` grows in 30-second batches (not per-ping), points in order
- [ ] Restart mid-shift resumes tracking and reattaches to the open trip without PIN
- [ ] Engine unit tests on seams: policy-driven write decisions, trail batching, resume conditions
