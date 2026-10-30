/// Firebase bootstrap & anonymous session (Ticket 02).
///
/// Boot wiring, in order:
/// 1. Hive (local first-launch flag storage) — see [openBootstrapFlagBox].
/// 2. `Firebase.initializeApp` with [firebaseOptions] (emulator options by
///    default; PRD-2 0.10).
/// 3. Emulator wiring for Firestore/Auth ([_wireEmulators]).
/// 4. Anonymous sign-in so launch/screens can read `vans`/`wards`/`routes`
///    (_spec § Implementation Decisions; PRD-2 0.8 rules allow anonymous
///    reads of those collections). Failures degrade the app instead of
///    crashing it (Ticket 02).
/// 5. FCM init with auto token acquisition ON (no permission request yet —
///    that belongs to the tracking ticket) and a one-time subscription to
///    topic `all` ([ensureSubscribedToAllTopic], PRD-2 0.6.6).
///
/// UI state is observable (and awaitable) through [bootstrapProvider].
/// `main()` is fire-and-forget: the app NEVER hard-crashes when the
/// emulator suite is unavailable — it boots into [BootstrapStatus.degraded]
/// and retries silently.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driverapp/features/tracking/offline/data/hive_firestore_timestamp_adapter.dart';
import 'package:driverapp/features/tracking/offline/offline_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// Platform-interface internals, used exactly once in the two-engine adopt
// path: resetting `MethodChannelFirebase.isCoreInitialized` is the only lever
// the public API leaves to re-sync the Dart-side app registry with native.
// Transitive dependency of `firebase_core`; stays unlisted (contract 0.10).
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart'
    show MethodChannelFirebase;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_options.dart';

/// FCM topic every app subscribes to on first launch (PRD-2 0.6.6).
/// Kept local to this module; contract 0.4 defines no constant for it.
const String fcmTopicAll = 'all';

/// Hive box holding this install's bootstrap flags.
const String bootstrapFlagBoxName = 'bootstrap';

/// Flag key: this install already subscribed to topic `all`.
const String subscribedAllFlagKey = 'subscribedAll';

/// Boot phase observable by the app (Ticket 02).
sealed class BootstrapStatus {
  const BootstrapStatus();

  const factory BootstrapStatus.pending() = BootstrapPending;

  /// Firebase is initialized, an anonymous session is held, FCM is wired.
  const factory BootstrapStatus.ready({
    required String anonymousUid,
  }) = BootstrapReady;

  /// Firebase/emulator unavailable: app keeps working locally and retries
  /// silently. A later success upgrades the state to [BootstrapReady].
  const factory BootstrapStatus.degraded({Object? error}) = BootstrapDegraded;
}

final class BootstrapPending extends BootstrapStatus {
  const BootstrapPending();
}

final class BootstrapReady extends BootstrapStatus {
  const BootstrapReady({required this.anonymousUid});

  final String anonymousUid;
}

final class BootstrapDegraded extends BootstrapStatus {
  const BootstrapDegraded({this.error});

  final Object? error;
}

/// Boot status observable/awaitable by the app (Ticket 02).
final bootstrapProvider = NotifierProvider<BootstrapController, BootstrapStatus>(
  BootstrapController.new,
);

/// Holds the boot state; `main()` starts [run], the app can watch
/// [bootstrapProvider] or await the controller's [done] future.
// Not `final`: tests extend this controller to simulate a degraded boot
// without touching platform channels.
class BootstrapController extends Notifier<BootstrapStatus> {
  Completer<BootstrapStatus>? _done;

  @override
  BootstrapStatus build() => const BootstrapStatus.pending();

  /// The app can await this to know when boot wiring has first resolved
  /// (ready or degraded). Re-check [bootstrapProvider] afterwards: silent
  /// retries may still upgrade a degraded boot to ready.
  Future<BootstrapStatus> done() =>
      (_done ??= Completer<BootstrapStatus>()).future;

  /// Starts (or resumes) boot wiring. Never throws (Ticket 02).
  Future<void> run({FirebaseBackend? backend}) async {
    if (_running) return;
    _running = true;
    final effectiveBackend = backend ?? defaultBackend();
    final progress = _BootProgress();
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        await _runOnce(progress, effectiveBackend);
        state = BootstrapStatus.ready(anonymousUid: progress.anonymousUid!);
        break;
      } catch (error, stackTrace) {
        state = BootstrapStatus.degraded(error: error);
        _done ??= Completer<BootstrapStatus>()..complete(state);
        // Degrade, never crash; retry silently in the background (Ticket 02).
        assert(() {
          // Development-only trace of degraded boots; no UI change (AVV rule).
          // ignore: avoid_print
          print('driverapp bootstrap degraded (attempt $attempt): $error\n'
              '$stackTrace');
          return true;
        }());
        await Future<void>.delayed(bootstrapRetryDelay(attempt));
      }
    }
    _done ??= Completer<BootstrapStatus>()..complete(state);
  }

  bool _running = false;

  // ---------------------------------------------------------------------------
  // Test seams — platform channels do not exist in unit tests (Ticket 02).
  // Each defaults to the real implementation; tests swap in doubles, the same
  // injection pattern as the [FirebaseBackend] parameter of [run].
  // ---------------------------------------------------------------------------

  /// Opens the Hive flag box ([openBootstrapFlagBox] without path_provider).
  @visibleForTesting
  Future<FlagBox> Function() openFlagBox = openBootstrapFlagBox;

  /// The `Firebase.initializeApp` step — the seam the two-engine
  /// "already exists" adopt fix is tested through
  /// (test/bootstrap/firebase_adopt_test.dart).
  @visibleForTesting
  Future<FirebaseApp> Function(FirebaseBackend backend) initializeApp =
      _defaultInitializeApp;

  /// Anonymous sign-in (Auth platform channel).
  @visibleForTesting
  Future<String> Function(FirebaseApp app) signInAnonymously =
      _defaultSignInAnonymously;

  /// FCM gateway; production uses [FirebaseMessagingGateway].
  @visibleForTesting
  MessagingGateway messagingGateway = const FirebaseMessagingGateway();

  Future<void> _runOnce(_BootProgress progress, FirebaseBackend backend) async {
    // 1. Local flag storage (first-launch detection).
    progress.flagBox ??= await openFlagBox();
    // 2. Firebase core — with the two-engine "already exists" adopt fix
    //    (see [_initializeFirebaseApp]).
    progress.app ??= await _initializeFirebaseApp(backend);
    // 3. Emulator wiring (before any Firestore/Auth use).
    if (!progress.emulatorsWired && backend == FirebaseBackend.emulatorSuite) {
      _wireEmulators(progress.app!);
      progress.emulatorsWired = true;
    }
    // 4. Anonymous session at launch.
    progress.anonymousUid ??= await signInAnonymously(progress.app!);
    // 5. FCM: init + one-time topic `all` subscription.
    if (!progress.messagingReady) {
      await messagingGateway.init();
      progress.messagingReady = true;
    }
    if (!progress.allSubscribed) {
      await ensureSubscribedToAllTopic(
        flags: progress.flagBox!,
        messaging: messagingGateway,
      );
      progress.allSubscribed = true;
    }
  }

  /// Firebase core with ONE deliberate deviation from a plain retry loop: a
  /// PlatformException(IllegalStateException, "...already exists!") is
  /// ADOPTED instead of rethrown, because retrying can never recover from it.
  Future<FirebaseApp> _initializeFirebaseApp(FirebaseBackend backend) async {
    try {
      return await initializeApp(backend);
    } on PlatformException catch (error) {
      if (error.code != 'IllegalStateException' ||
          !(error.message?.contains('already exists') ?? false)) {
        rethrow; // every other failure keeps degrading exactly as before.
      }
      // Samsung letterbox relaunch (M215F, logcat 2026-10-28): while the
      // first Flutter engine is still warming up, a letterbox activity
      // relaunch can start a SECOND engine in the same process (Geolocator
      // log: "Connected engine count 2"). Both engines run main(), and their
      // `initializeApp` calls race; the loser's native create throws
      // PlatformException(IllegalStateException, "FirebaseApp name [DEFAULT]
      // already exists!") on EVERY retry, so that engine degraded forever.
      // A Firebase app is process-wide state — ADOPT the winner's app.
      try {
        return Firebase.app(defaultFirebaseAppName);
      } on FirebaseException catch (adoptError) {
        if (adoptError.code != 'no-app') rethrow;
        // Device-true subtlety: this isolate last synced its Dart-side app
        // registry with native BEFORE the other engine's create completed, so
        // `Firebase.app` cannot see the app yet — and re-running
        // `initializeApp` would only rethrow the same exception forever (the
        // proven never-recovers behavior). Force one re-sync of the registry
        // from native, then adopt what native reports.
        // ignore: invalid_use_of_visible_for_testing_member
        MethodChannelFirebase.isCoreInitialized = false;
        return await initializeApp(backend);
      }
    }
  }
}

final class _BootProgress {
  FlagBox? flagBox;
  FirebaseApp? app;
  bool emulatorsWired = false;
  String? anonymousUid;
  bool messagingReady = false;
  bool allSubscribed = false;
}

/// Real `Firebase.initializeApp` behind [BootstrapController.initializeApp]:
/// the single name/options pair the app boots with.
Future<FirebaseApp> _defaultInitializeApp(FirebaseBackend backend) =>
    Firebase.initializeApp(
      name: defaultFirebaseAppName,
      options: firebaseOptions(backend),
    );

/// Real anonymous sign-in behind [BootstrapController.signInAnonymously]
/// (Auth platform channel — moved out of the controller so tests can inject
/// a double).
Future<String> _defaultSignInAnonymously(FirebaseApp app) async {
  final credential =
      await FirebaseAuth.instanceFor(app: app).signInAnonymously();
  final user = credential.user;
  if (user == null) {
    throw StateError('signInAnonymously returned no user (Ticket 02)');
  }
  return user.uid;
}

/// Boot wiring entry point. Fire-and-forget from `main()` — never throws
/// (Ticket 02); UI observes [bootstrapProvider] / awaits `done()`.
Future<void> runBootstrap(ProviderContainer container) async {
  // F-D7 wiring lives here (not main.dart) because the boot container is
  // the umbrella. Hive cannot serialize the Firestore `Timestamp` values
  // carried by trail points — register once, before ANY feature box opens.
  if (!Hive.isAdapterRegistered(207)) {
    Hive.registerAdapter(FirestoreTimestampAdapter());
  }
  // Firebase boot FIRST — the offline sync drain reads Firestore through
  // `firebaseFirestoreProvider`, and with no Firebase app that read throws
  // `[core/no-app]` every launch (observed defect on device: the service
  // never started because it was read before `.run()` initialized app).
  // `.run()` never throws; it only degrades internally, so starting the
  // drain after it (ready OR degraded) is always well-defined.
  await container.read(bootstrapProvider.notifier).run();
  // The sync drain starts with boot and is idempotent; a host without
  // platform channels (tests, CLI) just logs and boots on (ticket 02 rule).
  try {
    container.read(offlineSyncServiceProvider).start();
  } catch (error) {
    debugPrint('bootstrap: offline sync service not started: $error');
  }
}

/// Silent-retry backoff, `attempt` is 1-based. Cheap calls first so a
/// missing emulator fails fast locally, but a flaky network on the road
/// still gets retried forever without spamming.
Duration bootstrapRetryDelay(int attempt) =>
    Duration(seconds: switch (attempt) { 1 => 2, 2 => 10, _ => 30 });

// ---------------------------------------------------------------------------
// Emulator wiring
// ---------------------------------------------------------------------------

/// Points Firestore/Auth at the local Emulator Suite (Ticket 02, PRD-2
/// 0.10). Ports 8080 (Firestore) and 9099 (Auth) per Ticket 02; host via
/// [kFirebaseEmulatorHost].
///
/// Cloud Functions (port 5001) is wired in [_wireEmulators]; the old
/// `verifyDriverPin` callable is DELETED from the app (0.16 code login; the
/// Function itself stays deployed until the backend sweep).
void _wireEmulators(FirebaseApp app) {
  FirebaseFirestore.instanceFor(app: app)
      .useFirestoreEmulator(kFirebaseEmulatorHost, kFirestoreEmulatorPort);
  FirebaseAuth.instanceFor(app: app)
      .useAuthEmulator(kFirebaseEmulatorHost, kAuthEmulatorPort);
}

// ---------------------------------------------------------------------------
// FCM gateway seam
// ---------------------------------------------------------------------------

/// FCM seam so logic above stays testable without platform channels
/// (Ticket 02 note: FCM calls must not hit network in tests).
abstract interface class MessagingGateway {
  /// Turns automatic FCM token acquisition ON. Must NOT request the
  /// notifications permission — that belongs to the tracking ticket.
  Future<void> init();

  /// Subscribes this install to an FCM topic.
  Future<void> subscribeToTopic(String topic);
}

/// Real gateway (production runs).
final class FirebaseMessagingGateway implements MessagingGateway {
  const FirebaseMessagingGateway();

  @override
  Future<void> init() => FirebaseMessaging.instance.setAutoInitEnabled(true);

  @override
  Future<void> subscribeToTopic(String topic) =>
      FirebaseMessaging.instance.subscribeToTopic(topic);
}

/// No-op double used by tests (and safe as a degraded fallback).
final class NoopMessagingGateway implements MessagingGateway {
  const NoopMessagingGateway();

  @override
  Future<void> init() async {}

  @override
  Future<void> subscribeToTopic(String topic) async {}
}

// ---------------------------------------------------------------------------
// First-launch flag (topic `all`, PRD-2 0.6.6)
// ---------------------------------------------------------------------------

/// Tiny storage seam over the Hive box; fakes implement this in tests.
abstract interface class FlagBox {
  bool? getBool(String key);

  Future<void> putBool(String key, bool value);
}

/// Hive-backed flag box (hive_flutter is already a dependency).
final class HiveFlagBox implements FlagBox {
  HiveFlagBox(this._box);

  final Box<bool> _box;

  @override
  bool? getBool(String key) => _box.get(key);

  @override
  Future<void> putBool(String key, bool value) => _box.put(key, value);
}

/// Opens (and lazily creates) the Hive flag box. Uses hive_flutter's
/// bundled path_provider setup; the app works without it only in degraded
/// boot paths, so a platform-channel failure here degrades like any other.
Future<FlagBox> openBootstrapFlagBox() async {
  await Hive.initFlutter();
  final box = await Hive.openBox<bool>(bootstrapFlagBoxName);
  return HiveFlagBox(box);
}

/// Subscribes this install to topic `all` exactly once (PRD-2 0.6.6):
/// the first-launch flag is written ONLY after a successful subscription, so
/// a restart after a failed attempt retries. Idempotent across restarts.
///
/// Returns whether the subscription happened now (`false` = already done).
Future<bool> ensureSubscribedToAllTopic({
  required FlagBox flags,
  required MessagingGateway messaging,
  String topic = fcmTopicAll,
}) async {
  if (flags.getBool(subscribedAllFlagKey) ?? false) return false;
  await messaging.subscribeToTopic(topic);
  await flags.putBool(subscribedAllFlagKey, true);
  return true;
}
