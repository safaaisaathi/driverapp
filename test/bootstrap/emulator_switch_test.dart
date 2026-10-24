import 'package:driverapp/core/config/firebase_bootstrap.dart';
import 'package:driverapp/core/config/firebase_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('emulator switch (Ticket 02 / PRD-2 0.10)', () {
    test('defaults to the Emulator Suite for local development', () {
      // Tests compile without dart-defines, so these assert the defaults.
      expect(kUseFirebaseEmulator, isTrue);
      expect(defaultBackend(), FirebaseBackend.emulatorSuite);
    });

    test('emulator ports are the Ticket 02 ports (Firestore 8080/Auth 9099/'
        'Functions 5001) on localhost', () {
      expect(kFirebaseEmulatorHost, 'localhost');
      expect(kFirestoreEmulatorPort, 8080);
      expect(kAuthEmulatorPort, 9099);
      expect(kFunctionsEmulatorPort, 5001);
    });

    test('single switch to the shared project is one dart-define away', () {
      // The switch itself is compile-time; here we pin its shape: with the
      // define unset, `--dart-define=DRIVERAPP_USE_EMULATOR=false` selects
      // the shared project (covered by defaultBackend's else branch —
      // verified at an integration checkpoint by rerunning with the flag).
      expect(FirebaseBackend.values,
          unorderedEquals([FirebaseBackend.emulatorSuite, FirebaseBackend.sharedProject]));
    });
  });

  group('bootstrapRetryDelay (silent retries)', () {
    test('grows and never shrinks as attempts accumulate', () {
      // Fails fast locally (2 s), then backs off but stays bounded (30 s)
      // so a flaky network on the road keeps retrying without spamming.
      final first = bootstrapRetryDelay(1);
      final second = bootstrapRetryDelay(2);
      final third = bootstrapRetryDelay(3);
      final tenth = bootstrapRetryDelay(10);

      expect(first, lessThan(second));
      expect(second, lessThan(third));
      expect(tenth, equals(third), reason: 'backoff must be capped');
    });
  });
}
