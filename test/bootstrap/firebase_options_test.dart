import 'package:driverapp/core/config/firebase_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('emulatorFirebaseOptions (placeholder shape)', () {
    test('targets the ONE shared project, on both backends (CHG-0008)', () {
      final emulator = firebaseOptions(FirebaseBackend.emulatorSuite);

      // Every backend is safaaisaathi-63a87. There is no second project id
      // in the app any more (the old demo placeholder is gone).
      expect(emulator.projectId, 'safaaisaathi-63a87');
    });

    test('every required field is a non-empty placeholder', () {
      final options = emulatorFirebaseOptions();

      expect(options.apiKey, isNotEmpty);
      expect(options.appId, isNotEmpty);
      expect(options.messagingSenderId, isNotEmpty);
      expect(options.storageBucket, isNotEmpty);
    });

    test('options source is a single pure function over the backend', () {
      // Switching backends never rewrites call sites: one function decides.
      expect(firebaseOptions(FirebaseBackend.emulatorSuite).projectId,
          emulatorFirebaseOptions().projectId);
    });

    test('shared-project options refuse to boot without real keys (0.10)', () {
      expect(
        () => firebaseOptions(FirebaseBackend.sharedProject),
        throwsUnimplementedError,
      );
    });
  });
}
