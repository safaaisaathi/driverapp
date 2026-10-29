/// Seam for the four permission stages of F-D2 step 1, in contract order:
/// while-in-use location → background location → notifications →
/// battery-optimization exemption.
library;

/// The contract order (PRD-2 F-D2 step 1). Exhaustive constant so no stage
/// can be skipped or reordered accidentally.
enum TrackingPermissionStage {
  locationWhileInUse,
  locationBackground,
  notifications,
  batteryOptimization,
}

/// Outcome of asking one stage.
enum PermissionApproval {
  granted,

  /// Denied (or permanently denied). The caller shows the localized
  /// clear state; nothing crashes.
  denied,

  /// Device location (GPS) master switch is off. Applies to the location
  /// stages only.
  gpsOff,
}

/// One "ask permission" call per stage; repeated requests just re-check.
abstract class TrackingPermissionGateway {
  /// While-in-use location access (Android: ACCESS_FINE_LOCATION).
  Future<PermissionApproval> ensureLocationWhileInUse();

  /// "Allow all the time" access (Android: ACCESS_BACKGROUND_LOCATION,
  /// delivered through the app-settings screen — geolocator has no direct
  /// background request API; ruling recorded in the ticket report).
  Future<PermissionApproval> ensureLocationBackground();

  /// Notification permission (Android 13+ POST_NOTIFICATIONS) so the
  /// persistent "Tracking active" service notification is visible.
  Future<PermissionApproval> ensureNotifications();

  /// Battery-optimization exemption so the service survives Doze through
  /// long shifts (flutter_foreground_task's dedicated API).
  Future<PermissionApproval> ensureBatteryOptimizationExemption();

  /// Check current permission status WITHOUT prompting the user.
  /// Used by UI layer to decide whether to show rationale screens.
  Future<PermissionApproval> checkLocationWhileInUse();

  /// Check current background location permission status.
  Future<PermissionApproval> checkLocationBackground();

  /// Check current notification permission status.
  Future<PermissionApproval> checkNotifications();

  /// Check current battery optimization exemption status.
  Future<PermissionApproval> checkBatteryOptimization();
}
