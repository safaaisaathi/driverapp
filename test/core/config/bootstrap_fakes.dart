/// Test doubles for the Firebase bootstrap seam (ticket 8).
///
/// The splash routes once the boot ANSWERS (ready or degraded), so every
/// test that pumps the splash needs a boot it controls — without touching
/// Firebase, Auth, FCM or Hive (no platform channel in a unit test).
library;

import 'package:driverapp/core/config/firebase_bootstrap.dart';
import 'package:driverapp/core/config/firebase_options.dart' show FirebaseBackend;

/// A bootstrap whose status the test controls.
///
/// [initial] is the status the provider builds with (`pending` = "the boot
/// has not answered yet"); [resolve] flips it later, exactly like the real
/// controller does when the boot finishes.
final class FakeBootstrapController extends BootstrapController {
  FakeBootstrapController({this.initial = const BootstrapStatus.pending()});

  /// The status the provider builds with.
  final BootstrapStatus initial;

  @override
  BootstrapStatus build() => initial;

  @override
  Future<void> run({FirebaseBackend? backend}) async {
    state = initial;
  }

  /// The boot answers now (ready or degraded).
  void resolve(BootstrapStatus status) => state = status;
}
