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

/// Functions emulator port (Ticket 02; wired in firebase_bootstrap.dart).
const int kFunctionsEmulatorPort = 5001;

/// THE single options source. Everything else calls this.
FirebaseOptions firebaseOptions(FirebaseBackend backend) => switch (backend) {
      FirebaseBackend.emulatorSuite => emulatorFirebaseOptions(),
      FirebaseBackend.sharedProject => sharedProjectFirebaseOptions(),
    };

/// Backend selected from the dart-define flags (no call-site branching).
FirebaseBackend defaultBackend() =>
    kUseFirebaseEmulator ? FirebaseBackend.emulatorSuite : FirebaseBackend.sharedProject;

/// PLACEHOLDER — the emulator suite only, contract 0.10 secrets rule.
///
/// EVERY backend is the one shared project `safaaisaathi-63a87` (CHG-0008);
/// there is no second project id anywhere in the app. Every endpoint talk
/// target is wired explicitly to the Emulator Suite (firebase_bootstrap.dart),
/// so the placeholder key/app id never reach real Google servers and can
/// never leak or spend real quota. The real (non-emulator) values arrive at
/// run time through the dart-defines in [sharedProjectFirebaseOptions].
FirebaseOptions emulatorFirebaseOptions() => const FirebaseOptions(
      apiKey: 'demo-placeholder-key',
      appId: '1:000000000000:android:com.sfic.driverapp',
      messagingSenderId: '000000000000',
      projectId: 'safaaisaathi-63a87',
      storageBucket: 'safaaisaathi-63a87.firebasestorage.app',
      authDomain: 'safaaisaathi-63a87.firebaseapp.com',
    );

/// Real (shared) project options — supplied at RUN TIME via dart-define
/// (contract 0.10: keys are shared privately, never committed to the repo).
///
/// Supply the four values on the run command:
/// ```
/// flutter run \
///   --dart-define=DRIVERAPP_USE_EMULATOR=false \
///   --dart-define=DRIVERAPP_FB_API_KEY=<key> \
///   --dart-define=DRIVERAPP_FB_APP_ID=<appId> \
///   --dart-define=DRIVERAPP_FB_SENDER_ID=<messagingSenderId>
/// ```
/// (projectId/storageBucket below are project-derived, not secrets.)
///
/// Throws so that flipping [kUseFirebaseEmulator] off without the defines
/// fails loudly into the bootstrap's degraded state instead of silently
/// hitting a half-configured project. Values come from
/// `flutterfire configure` (or the Firebase console) on each machine.
FirebaseOptions sharedProjectFirebaseOptions() {
  final apiKey = const String.fromEnvironment('DRIVERAPP_FB_API_KEY');
  final appId = const String.fromEnvironment('DRIVERAPP_FB_APP_ID');
  final senderId = const String.fromEnvironment('DRIVERAPP_FB_SENDER_ID');

  if (apiKey.isEmpty || appId.isEmpty || senderId.isEmpty) {
    throw UnimplementedError(
      'Real Firebase options not supplied (contract 0.10: keys are shared '
      'privately, never committed). Run with --dart-define='
      'DRIVERAPP_FB_API_KEY / _FB_APP_ID / _FB_SENDER_ID — get the values '
      'from `flutterfire configure` output on this machine.',
    );
  }

  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: 'safaaisaathi-63a87',
    storageBucket: 'safaaisaathi-63a87.firebasestorage.app',
    authDomain: 'safaaisaathi-63a87.firebaseapp.com',
  );
}
