# 03: Pure domain services (Write Policy, distance, ward order, Today)

**What to build:** The contract's calculable rules as pure, testable functions (spec seam 2), no Firebase, no Flutter widgets: the **Write Policy** (0.13: write only if moved ≥ `minMoveM` since last written point OR `heartbeatSec` elapsed; interval `gpsIntervalSec`, `gpsIntervalLowBatterySec` below `lowBatteryPct`), haversine distance vs ward `radiusM` (decides `flagged`), ward-order helpers (next undone ward in `routes.wardIds` order; which undone wards are "out of order"), and **Today** (grilled decision: calendar date resolved in Asia/Kolkata regardless of device settings). These exist to be consumed by the tracking engine and screens.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] Write Policy accepts (candidate point, lastWritten point, lastWriteTime, batteryPct, now) and decides write/skip/interval with the exact contract constants; stopped-van heartbeat never lets a stationary van look dead
- [ ] Haversine distance helper correct to a metre tolerance on known coordinates; flag decision = position outside `radiusM` of the ward centre
- [ ] Ward-order helpers: next undone ward in route order; list of undone wards and which would be out-of-order given current order
- [ ] Today resolves to the IST calendar date across midnight edge cases and non-IST device timezones
- [ ] Every function unit-tested without Flutter mocking; `flutter analyze` clean
