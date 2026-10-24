/// Seam for network connectivity (F-D7): the small injectable interface
/// mirroring the tracking engine's other collaborators — tests drive a fake
/// (spec: tests mock seams, never a device); the real implementation wraps
/// `connectivity_plus` (see `data/`).
library;

/// Network reachability source for the offline sync service.
abstract class ConnectivitySource {
  /// `true` = some network interface is reachable, `false` = none.
  ///
  /// Contract for implementers: emits the CURRENT state right after listen
  /// (so a fresh service start flushes immediately when already online),
  /// then on every change, never erroring.
  Stream<bool> get status;
}
