/// Test fakes for the `TrackingPermissionGateway` seam (ticket 6, 0.16).
///
/// The real gateway is Geolocator-backed (tracking_providers.dart); these
/// fakes keep the launching-chain widget tests off platform channels.
/// The gateway's `check*` methods decide whether a rationale screen shows,
/// so the grant-all fake completes the setup without any rationale and the
/// deny-all fake exercises the "Not now" skip path.
library;

import 'package:driverapp/features/tracking/tracking_providers.dart'
    show PermissionApproval, TrackingPermissionGateway;

/// Every stage reports already granted: the one-time setup completes
/// without ever showing a rationale screen.
class GrantAllPermissionGateway implements TrackingPermissionGateway {
  const GrantAllPermissionGateway();

  @override
  Future<PermissionApproval> ensureLocationWhileInUse() async =>
      PermissionApproval.granted;

  @override
  Future<PermissionApproval> ensureLocationBackground() async =>
      PermissionApproval.granted;

  @override
  Future<PermissionApproval> ensureNotifications() async =>
      PermissionApproval.granted;

  @override
  Future<PermissionApproval> ensureBatteryOptimizationExemption() async =>
      PermissionApproval.granted;

  @override
  Future<PermissionApproval> checkLocationWhileInUse() async =>
      PermissionApproval.granted;

  @override
  Future<PermissionApproval> checkLocationBackground() async =>
      PermissionApproval.granted;

  @override
  Future<PermissionApproval> checkNotifications() async =>
      PermissionApproval.granted;

  @override
  Future<PermissionApproval> checkBatteryOptimization() async =>
      PermissionApproval.granted;
}

/// Every stage reports denied BEFORE any rationale: each stage shows the
/// rationale screen and "Not now" ends the flow at the first stage. The
/// fresh-device path must still complete (0.16: the app stays fully
/// usable in degraded mode, nothing crashes).
class DenyAllPermissionGateway implements TrackingPermissionGateway {
  const DenyAllPermissionGateway();

  @override
  Future<PermissionApproval> ensureLocationWhileInUse() async =>
      PermissionApproval.denied;

  @override
  Future<PermissionApproval> ensureLocationBackground() async =>
      PermissionApproval.denied;

  @override
  Future<PermissionApproval> ensureNotifications() async =>
      PermissionApproval.denied;

  @override
  Future<PermissionApproval> ensureBatteryOptimizationExemption() async =>
      PermissionApproval.denied;

  @override
  Future<PermissionApproval> checkLocationWhileInUse() async =>
      PermissionApproval.denied;

  @override
  Future<PermissionApproval> checkLocationBackground() async =>
      PermissionApproval.denied;

  @override
  Future<PermissionApproval> checkNotifications() async =>
      PermissionApproval.denied;

  @override
  Future<PermissionApproval> checkBatteryOptimization() async =>
      PermissionApproval.denied;
}
