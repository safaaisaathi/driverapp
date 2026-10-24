/// Firebase backend selection (PRD-2 section 0.10).
///
/// Local development always runs against the Firebase Emulator Suite; the
/// shared demo project (`asia-south1`) is used only at integration
/// checkpoints. The options source is ONE function ([firebaseOptions]) so
/// switching backends later never touches call sites.
///
/// Secrets rule (0.10): no keys in the repo. The emulator options below are
/// placeholders by design; real values are supplied privately when the owner
/// provides them.
// TODO(demo): before the demo, point the app at the real shared project by
// running `flutter run --dart-define=DRIVERAPP_USE_EMULATOR=false` AND
// replacing [sharedProjectFirebaseOptions] with the real generated config
// (`flutterfire configure`, then paste the values here — still not committed:
// keep them in a private override or local untracked file per 0.10).
library;
import 'package:firebase_core/firebase_core.dart';

/// Which Firebase backend the app talks to.
enum FirebaseBackend {
  /// Local Firebase Emulator Suite (default for development, 0.10).
  emulatorSuite,

  /// The shared demo project, used only at integration checkpoints (0.10).
  sharedProject,
}

/// Dart-define switch for the emulator wiring. Default ON for now (Ticket 02).
///
/// Integration checkpoint: `--dart-define=DRIVERAPP_USE_EMULATOR=false`.
const bool kUseFirebaseEmulator = bool.fromEnvironment(
  'DRIVERAPP_USE_EMULATOR',
  defaultValue: true,
);

/// Host that serves the Emulator Suite. `localhost` covers the standard
/// setup (adb reverse / AVD networking variants can override it, e.g.
/// `--dart-define=DRIVERAPP_EMULATOR_HOST=10.0.2.2` on an AVD, or a LAN IP
/// for a physical phone).
const String kFirebaseEmulatorHost = String.fromEnvironment(
  'DRIVERAPP_EMULATOR_HOST',
  defaultValue: 'localhost',
);

/// Firestore emulator port (Ticket 02).
const int kFirestoreEmulatorPort = 8080;

/// Auth emulator port (Ticket 02).
const int kAuthEmulatorPort = 9099;

/// Functions emulator port (Ticket 02; wired when `cloud_functions` is
/// added by the PIN/verifyDriverPin ticket — see firebase_bootstrap.dart).
const int kFunctionsEmulatorPort = 5001;

/// THE single options source. Everything else calls this.
FirebaseOptions firebaseOptions(FirebaseBackend backend) => switch (backend) {
      FirebaseBackend.emulatorSuite => demoFirebaseOptions(),
      FirebaseBackend.sharedProject => sharedProjectFirebaseOptions(),
    };

/// Backend selected from the dart-define flags (no call-site branching).
FirebaseBackend defaultBackend() =>
    kUseFirebaseEmulator ? FirebaseBackend.emulatorSuite : FirebaseBackend.sharedProject;

/// PLACEHOLDER — replace via firebase_options/real config when the owner
/// supplies keys, contract 0.10 secrets rule.
///
/// Targets the project id `driver-app-demo` assigned by Ticket 02. Every
/// endpoint talk target is wired explicitly to the Emulator Suite
/// (firebase_bootstrap.dart), so this placeholder configuration never
/// reaches real Google servers and can never leak or spend real quota.
FirebaseOptions demoFirebaseOptions() => const FirebaseOptions(
      apiKey: 'demo-placeholder-key',
      appId: '1:000000000000:android:com.sfic.driverapp',
      messagingSenderId: '000000000000',
      projectId: 'driver-app-demo',
      storageBucket: 'driver-app-demo.appspot.com',
      authDomain: 'driver-app-demo.firebaseapp.com',
    );

/// Real (shared) project options — NOT supplied yet.
///
/// Throws so that flipping [kUseFirebaseEmulator] off before the owner
/// delivers the private config fails loudly into the bootstrap's degraded
/// state instead of silently hitting a half-configured project.
FirebaseOptions sharedProjectFirebaseOptions() => throw UnimplementedError(
      'Real Firebase options not supplied yet (contract 0.10: keys are '
      'shared privately, never committed). Paste the values from '
      '`flutterfire configure` into this function when the owner provides '
      'them, then run with --dart-define=DRIVERAPP_USE_EMULATOR=false.',
    );
