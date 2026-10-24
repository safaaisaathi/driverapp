/// Seam for the Android foreground service (F-D2 step 2): the engine only
/// needs start/stop; the platform adapter owns notification options.
library;

enum ForegroundServiceStartResult {
  started,

  failed,
}

/// The two localized strings of the persistent service notification are the
/// only UI strings the engine passes through (report: single allowed
/// service-notification exception).
abstract class ForegroundServiceHandle {
  Future<ForegroundServiceStartResult> start({
    required String notificationTitle,
    required String notificationBody,
    required String vanId,
  });

  Future<bool> stop();
}
