/// Shared contract constants — PRD-2 section 0.4.
///
/// Names EXACTLY as in the contract. Do not rename, add or remove without
/// asking the Backend and Integration Owner (rule 0.15.4).
library;

/// Seconds between location checks while on shift.
const int gpsIntervalSec = 10;

/// Seconds between location checks when battery is low.
const int gpsIntervalLowBatterySec = 30;

/// Battery percentage below which the low-battery interval is used.
const int lowBatteryPct = 20;

/// Minutes without updates before a van on shift is marked offline.
const int offlineThresholdMin = 10;

/// Seconds after which a location is considered stale.
const int staleLocationSec = 60;

/// Metres from the next ward centre within which an arrival alert fires.
const int arrivalAlertRadiusM = 500;

/// Metres below which a new complaint counts as a duplicate of an open one.
const int duplicateRadiusM = 50;

/// Maximum complaints one device may file per day.
const int maxComplaintsPerDevicePerDay = 5;

/// Missed-collection reports for one ward in one day that alert the inspector.
const int missedReportThreshold = 3;

/// Hours after which an open complaint escalates to level 1.
const int escalationL1Hours = 24;

/// Hours after which an open complaint escalates to level 2.
const int escalationL2Hours = 48;

/// Average van speed (km/h) used in the prototype ETA when GPS speed is low.
const int avgVanSpeedKmph = 15;

/// Metres a van must move before a location write is worth making.
const int minMoveM = 15;

/// Seconds after the last write when a heartbeat write is made anyway.
const int heartbeatSec = 30;

/// Metres around `vans.depot` that count as "at the depot" for the auto-end
/// rule (ruling #29).
const double depotRadiusM = 500;

/// Continuous hours inside [depotRadiusM] after which the shift auto-ends
/// (ruling #29).
const int depotDwellLimitHours = 3;

/// Metres a van must move from its dwell anchor to restart the depot dwell
/// clock (ruling #29).
const double depotDwellResetM = 100;
