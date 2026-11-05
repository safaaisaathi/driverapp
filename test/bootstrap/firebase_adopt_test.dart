/// Unit tests for the two-engine `initializeApp` race fix (Ticket 02).
///
/// On a Samsung letterbox relaunch a SECOND Flutter engine can boot in the
/// same process while the first one is still warming up (Geolocator log:
/// "Connected engine count 2"). Both engines run `main()`, and their
/// `Firebase.initializeApp` calls race; the loser gets
/// PlatformException(IllegalStateException, "FirebaseApp name [DEFAULT]
/// already exists!") on every retry and, before the adopt fix, degraded
/// FOREVER (proven on device: Samsung M215F, logcat 2026-10-28).
///
/// The bootstrap must ADOPT the already-initialized app instead of looping.
///
/// Platform channels do not exist in unit tests, so the whole boot runs on
/// seams: a [FirebasePlatform] double simulates the native registry, and the
/// Hive/Auth/FCM steps get in-memory doubles.
library;

import 'dart:async';

import 'package:driverapp/core/config/firebase_bootstrap.dart';
import 'package:driverapp/core/config/firebase_options.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart'
    hide FirebaseOptions, defaultFirebaseAppName, FirebaseException;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    // Drop the per-test platform double: the Firebase facade caches its
    // delegate on first use, so a stale double would leak into the next test.
    // ignore: invalid_use_of_visible_for_testing_member
    Firebase.delegatePackingProperty = null;
    FirebasePlatform.instance = MethodChannelFirebase();
  });

  group('two-engine initializeApp race (adopt the existing app)', () {
    test('an "already exists" failure is adopted, not retried forever — '
        'the boot reaches ready', () async {
      // The rare-but-possible ordering: this engine's Dart-side registry
      // already sees the app, so `Firebase.app()` can adopt immediately.
      final harness = _boot(FakeFirebasePlatform(registrySynced: true));
      final resolved = _firstResolvedStatus(harness);
      harness.startBoot();

      final status = await resolved;

      expect(
        status,
        isA<BootstrapReady>(),
        reason: 'the winner\'s app must be adopted, not retried forever',
      );
      final ready = status as BootstrapReady;
      expect(ready.uid, isNull, reason: 'boot is wired but signed out');
      expect(
        harness.platform.initializeAppCalls,
        1,
        reason: 'the failed create must not be retried',
      );
      expect(
        harness.platform.appCalls,
        1,
        reason: 'the adoption reads the existing app',
      );
      expect(harness.messaging.subscribedTopics, [
        'all',
      ], reason: 'the whole boot wiring must have run after the adoption');
      expect(harness.flags.getBool(subscribedAllFlagKey), isTrue);
      harness.dispose();
    });

    test(
      'the device-true stale registry still adopts after one re-sync',
      () async {
        // What actually happens on the device: the loser's registry was synced
        // with native BEFORE the other engine's create completed, so
        // `Firebase.app()` cannot see the app yet — and re-running
        // initializeApp would only rethrow the same exception forever (the
        // proven never-recovers behavior). The adopt path must re-sync the
        // registry from native once, then adopt what native reports.
        final platform = FakeFirebasePlatform(registrySynced: false);
        final harness = _boot(platform);
        final resolved = _firstResolvedStatus(harness);
        harness.startBoot();

        final status = await resolved;

        expect(
          status,
          isA<BootstrapReady>(),
          reason: 'the re-sync must surface the winner\'s app',
        );
        final ready = status as BootstrapReady;
        expect(ready.uid, isNull, reason: 'boot is wired but signed out');
        expect(
          platform.initializeAppCalls,
          2,
          reason: 'exactly one re-sync attempt after the failed create',
        );
        expect(platform.appCalls, 1);
        expect(harness.messaging.subscribedTopics, ['all']);
        harness.dispose();
      },
    );

    test(
      'other initialize failures keep degrading (no adoption, no crash)',
      () async {
        final harness = _boot(FakeFirebasePlatform(registrySynced: true));
        harness.controller.initializeApp = (backend) async =>
            throw PlatformException(
              code: 'unavailable',
              message: 'channels not mocked',
            );
        final resolved = _firstResolvedStatus(harness);
        harness.startBoot();

        final status = await resolved;

        expect(
          status,
          isA<BootstrapDegraded>(),
          reason:
              'only "already exists" is adoptable; everything else '
              'keeps degrading as before the fix',
        );
        final degraded = status as BootstrapDegraded;
        final error = degraded.error;
        expect(error, isA<PlatformException>());
        expect((error as PlatformException).code, 'unavailable');
        expect(
          harness.platform.initializeAppCalls,
          0,
          reason: 'the failure must surface before the platform double',
        );
        // The degraded retry loop runs forever by design (Ticket 02), so the
        // container is NOT disposed here: disposing would make the loop's next
        // `state =` write throw (UnmountedRefException) out of the background.
        // The container dies with the test isolate at the end of the suite.
      },
    );
  });

  group('first-use gate milestone (issues #18/#21, CHG-0003)', () {
    test('a ready boot completes sessionReady the moment Firebase is up, '
        'and bootStarted tracks run()', () async {
      final harness = _boot(FakeFirebasePlatform(registrySynced: true));
      final controller = harness.container.read(bootstrapProvider.notifier);
      expect(
        controller.bootStarted,
        isFalse,
        reason: 'before run() there is no boot to wait for',
      );

      var sessionReady = false;
      unawaited(controller.sessionReady().then((_) => sessionReady = true));

      final resolved = _firstResolvedStatus(harness);
      harness.startBoot();
      expect(controller.bootStarted, isTrue);

      final status = await resolved;
      expect(status, isA<BootstrapReady>());
      await Future<void>.delayed(Duration.zero);
      expect(
        sessionReady,
        isTrue,
        reason: 'the first-use gate opens as soon as Firebase is up',
      );
      harness.dispose();
    });
  });
}

/// The boot harness: the real controller + real `run()` wiring, with every
/// platform boundary faked out.
_BootHarness _boot(FakeFirebasePlatform platform) => _BootHarness(platform);

/// Waits for the first RESOLVED boot state (ready or degraded). Tests observe
/// [bootstrapProvider] state changes instead of [BootstrapController.done]:
/// that completer only resolves when `run()` itself created it, so awaiting
/// it before the boot resolves would hang.
Future<BootstrapStatus> _firstResolvedStatus(_BootHarness harness) {
  final resolved = Completer<BootstrapStatus>();
  harness.container.listen(bootstrapProvider, (previous, next) {
    if (next is! BootstrapPending && !resolved.isCompleted) {
      resolved.complete(next);
    }
  });
  return resolved.future;
}

final class _BootHarness {
  _BootHarness(this.platform) {
    FirebasePlatform.instance = platform;
    controller.openFlagBox = () async => flags;
    // The default seam, but with test-safe options: the shared-project
    // options throw without dart-defines, and the platform double ignores
    // options anyway.
    controller.initializeApp = (backend) => Firebase.initializeApp(
      name: defaultFirebaseAppName,
      options: const FirebaseOptions(
        apiKey: 'test',
        appId: 'test-app-id',
        messagingSenderId: 'test-sender',
        projectId: 'safaaisaathi-63a87',
      ),
    );
    controller.messagingGateway = messaging;
    container = ProviderContainer(
      overrides: [bootstrapProvider.overrideWith(() => controller)],
    );
  }

  final FakeFirebasePlatform platform;
  final controller = BootstrapController();
  final FakeFlagBox flags = FakeFlagBox();
  final FakeMessagingGateway messaging = FakeMessagingGateway();
  late final ProviderContainer container;

  /// Starts the boot WITHOUT awaiting `run()`: the degraded retry loop runs
  /// forever by design (Ticket 02), so tests observe progress through
  /// [BootstrapController.done], which completes on the first resolved boot.
  void startBoot() {
    unawaited(
      container
          .read(bootstrapProvider.notifier)
          .run(
            // The backend only selects the emulator-wiring branch; the
            // initialize seam above supplies its own options, and wiring
            // emulators would touch Firestore/Auth platform instances.
            backend: FirebaseBackend.sharedProject,
          ),
    );
  }

  void dispose() => container.dispose();
}

/// In-memory stand-in for the Hive `_bootstrap` box (no real box: tests must
/// not touch platform channels or the file system).
final class FakeFlagBox implements FlagBox {
  final _store = <String, bool>{};

  @override
  bool? getBool(String key) => _store[key];

  @override
  Future<void> putBool(String key, bool value) async => _store[key] = value;
}

/// Records FCM traffic; nothing touches the platform channel.
final class FakeMessagingGateway implements MessagingGateway {
  var initCalls = 0;
  final subscribedTopics = <String>[];

  @override
  Future<void> init() async => initCalls++;

  @override
  Future<void> subscribeToTopic(String topic) async =>
      subscribedTopics.add(topic);

  @override
  Future<void> unsubscribeFromTopic(String topic) async =>
      subscribedTopics.remove(topic);
}

/// Platform double mirroring `MethodChannelFirebase`'s registry semantics:
/// the Dart-side registry only learns about an app when a core sync runs
/// (natively `initializeCore`, inside the first `initializeApp` call), and
/// the race LOSER's native create throws before any sync lands.
final class FakeFirebasePlatform extends FirebasePlatform {
  FakeFirebasePlatform({this.registrySynced = false});

  /// Whether `Firebase.app()` can already see `[DEFAULT]` on the Dart side.
  bool registrySynced;

  var initializeAppCalls = 0;
  var appCalls = 0;

  FirebaseAppPlatform get defaultApp => FirebaseAppPlatform(
    defaultFirebaseAppName,
    const FirebaseOptions(
      apiKey: 'test',
      appId: 'test-app-id',
      messagingSenderId: 'test-sender',
      projectId: 'safaaisaathi-63a87',
    ),
  );

  @override
  List<FirebaseAppPlatform> get apps => [if (registrySynced) defaultApp];

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    initializeAppCalls++;
    if (initializeAppCalls == 1) {
      // The other engine won the native create; this isolate's create call
      // throws before any registry sync (Samsung M215F, logcat 2026-10-28).
      throw PlatformException(
        code: 'IllegalStateException',
        message: 'FirebaseApp name [DEFAULT] already exists!',
      );
    }
    // The re-sync path: native core is initialized and reports the app the
    // other engine created.
    registrySynced = true;
    return defaultApp;
  }

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    appCalls++;
    if (!registrySynced) {
      // `noAppExists` (firebase_core_platform_interface): plugin 'core',
      // code 'no-app'.
      throw FirebaseException(
        plugin: 'core',
        code: 'no-app',
        message: "No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()",
      );
    }
    return defaultApp;
  }
}
