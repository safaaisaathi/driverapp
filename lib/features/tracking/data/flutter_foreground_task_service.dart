/// Real flutter_foreground_task-backed service handle (F-D2 step 2): the
/// persistent notification keeps the process alive while the engine (main
/// isolate) runs the location writes.
///
/// The package's own API also covers the notification permission
/// (`requestNotificationPermission`) and the battery-optimization
/// exemption (`requestIgnoreBatteryOptimization`) — used by the
/// permission gateway adapter.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../domain/foreground_service.dart';

/// Must be a top-level function returning the handler, so the service
/// isolate can re-create it after a process restart.
@pragma('vm:entry-point')
TrackingKeepAliveTaskHandler trackingTaskHandler() =>
    TrackingKeepAliveTaskHandler();

/// Task handler runs in the package's service isolate and does nothing but
/// exist cleanly: the actual tracking work lives in the MAIN isolate
/// (repositories + Write Policy stay single-owner). The service's job is
/// keeping the process alive (F-D2 step 2).
class TrackingKeepAliveTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

class FlutterForegroundTaskService implements ForegroundServiceHandle {
  const FlutterForegroundTaskService();

  /// The notification channel name/description are system-settings strings,
  /// not in-app UI strings (ticket report note).
  static const String notificationChannelName = 'Tracking';
  static const String notificationChannelId = 'driverapp_tracking';

  @override
  Future<ForegroundServiceStartResult> start({
    required String notificationTitle,
    required String notificationBody,
    required String vanId,
  }) async {
    try {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: notificationChannelId,
          channelName: notificationChannelName,
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
          showWhen: false,
        ),
        iosNotificationOptions: const IOSNotificationOptions(),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.nothing(),
          autoRunOnBoot: false,
          allowWakeLock: true,
        ),
      );

      final result = await FlutterForegroundTask.startService(
        serviceTypes: [ForegroundServiceTypes.location],
        notificationTitle: notificationTitle,
        notificationText: notificationBody,
        callback: trackingTaskHandler,
      );
      return result is ServiceRequestSuccess
          ? ForegroundServiceStartResult.started
          : ForegroundServiceStartResult.failed;
    } on Exception catch (error) {
      // Anything unexpected (service timeout, plugin not registered) is a
      // survivable start failure, never a crash.
      debugPrint('tracking: foreground service start failed: $error');
      return ForegroundServiceStartResult.failed;
    }
  }

  @override
  Future<bool> stop() async {
    try {
      final result = await FlutterForegroundTask.stopService();
      return result is ServiceRequestSuccess;
    } catch (error) {
      debugPrint('tracking: foreground service stop failed: $error');
      return false;
    }
  }
}
