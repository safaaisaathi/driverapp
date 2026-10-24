import 'package:driverapp/core/config/firebase_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('demoFirebaseOptions (placeholder shape)', () {
    test('targets the emulator demo project, never the shared project', () {
      final options = firebaseOptions(FirebaseBackend.emulatorSuite);

      // Ticket 02 assigns the emulator demo project id; the shared demo
      // project is reached only through `sharedProjectFirebaseOptions`.
      expect(options.projectId, 'driver-app-demo');
    });

    test('every required field is a non-empty placeholder', () {
      final options = demoFirebaseOptions();

      expect(options.apiKey, isNotEmpty);
      expect(options.appId, isNotEmpty);
      expect(options.messagingSenderId, isNotEmpty);
      expect(options.storageBucket, isNotEmpty);
    });

    test('options source is a single pure function over the backend', () {
      // Switching backends never rewrites call sites: one function decides.
      expect(firebaseOptions(FirebaseBackend.emulatorSuite).projectId,
          demoFirebaseOptions().projectId);
    });

    test('shared-project options refuse to boot without real keys (0.10)', () {
      expect(
        () => firebaseOptions(FirebaseBackend.sharedProject),
        throwsUnimplementedError,
      );
    });
  });
}
