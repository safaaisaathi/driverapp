/// Real permission gateway for the four contract stages (F-D2 step 1).
///
/// Platform mapping:
/// - while-in-use location: geolocator check/request (ACCESS_FINE_LOCATION).
/// - background location: "Allow all the time" — geolocator has no direct
///   background request API, so the adapter opens the app settings screen
///   and re-checks. Ruling recorded in the ticket report; real-device
///   verification is ticket 14's job.
/// - notifications: flutter_foreground_task.requestNotificationPermission
///   (Android 13+ POST_NOTIFICATIONS).
/// - battery exemption: flutter_foreground_task's
///   requestIgnoreBatteryOptimization (needs
///   REQUEST_IGNORE_BATTERY_OPTIMIZATIONS in the manifest).
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/permission_gateway.dart';

class GeolocatorTrackingPermissionGateway
    implements TrackingPermissionGateway {
  const GeolocatorTrackingPermissionGateway();

  @override
  Future<PermissionApproval> ensureLocationWhileInUse() async {
    final servicesOn = await _isLocationServiceOn();
    if (!servicesOn) return PermissionApproval.gpsOff;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }
    return _approvalFor(permission);
  }

  @override
  Future<PermissionApproval> ensureLocationBackground() async {
    final servicesOn = await _isLocationServiceOn();
    if (!servicesOn) return PermissionApproval.gpsOff;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always) {
      return PermissionApproval.granted;
    }

    // No request API for ACCESS_BACKGROUND_LOCATION: send the driver to the
    // app settings screen where "Allow all the time" lives, then take the
    // current state as the answer (never crashes; the flow reports the
    // denial and the app stays usable).
    final opened = await Geolocator.openAppSettings();
    debugPrint('tracking: openAppSettings returned $opened');
    final recheck = await Geolocator.checkPermission();
    if (recheck == LocationPermission.always) {
      return PermissionApproval.granted;
    }
    return PermissionApproval.denied;
  }

  @override
  Future<PermissionApproval> ensureNotifications() async {
    final permission = await FlutterForegroundTask
        .requestNotificationPermission();
    return permission == NotificationPermission.granted
        ? PermissionApproval.granted
        : PermissionApproval.denied;
  }

  @override
  Future<PermissionApproval> ensureBatteryOptimizationExemption() async {
    if (await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      return PermissionApproval.granted;
    }
    await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    final nowIgnoring =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    return nowIgnoring
        ? PermissionApproval.granted
        : PermissionApproval.denied;
  }

  @override
  Future<PermissionApproval> checkLocationWhileInUse() async {
    final servicesOn = await _isLocationServiceOn();
    if (!servicesOn) return PermissionApproval.gpsOff;

    final permission = await Geolocator.checkPermission();
    return _approvalFor(permission);
  }

  @override
  Future<PermissionApproval> checkLocationBackground() async {
    final servicesOn = await _isLocationServiceOn();
    if (!servicesOn) return PermissionApproval.gpsOff;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always) {
      return PermissionApproval.granted;
    }
    return PermissionApproval.denied;
  }

  @override
  Future<PermissionApproval> checkNotifications() async {
    final permission = await FlutterForegroundTask.checkNotificationPermission();
    return permission == NotificationPermission.granted
        ? PermissionApproval.granted
        : PermissionApproval.denied;
  }

  @override
  Future<PermissionApproval> checkBatteryOptimization() async {
    if (await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      return PermissionApproval.granted;
    }
    return PermissionApproval.denied;
  }

  Future<bool> _isLocationServiceOn() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (error) {
      debugPrint('tracking: location-service check failed (assume on): $error');
      // Platform failure is not a "no" — treat as enabled and let the
      // while-in-use stage produce the real answer.
      return true;
    }
  }

  PermissionApproval _approvalFor(LocationPermission permission) =>
      permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always
          ? PermissionApproval.granted
          : PermissionApproval.denied;
}
