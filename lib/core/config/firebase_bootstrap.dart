/// Firebase bootstrap (Ticket 02).
///
/// Boot wiring, in order:
/// 1. Hive (local first-launch flag storage) — see [openBootstrapFlagBox].
/// 2. `Firebase.initializeApp` with [firebaseOptions] (emulator options by
///    default; PRD-2 0.10).
/// 3. Emulator wiring for Firestore/Auth/Functions ([_wireEmulators]).
/// 4. FCM init with auto token acquisition ON (no permission request yet —
///    that belongs to the tracking ticket) and a one-time subscription to
///    topic `all` ([ensureSubscribedToAllTopic], PRD-2 0.6.6).
///
/// There is NO anonymous sign-in any more (CHG-0003): the session is the
/// driver's custom token, minted by `bindDeviceToVan` and applied by the
/// start-shift flow. A boot therefore finishes wired-but-signed-out, and the
/// screens that need data sign in first.
///
/// UI state is observable (and awaitable) through [bootstrapProvider].
/// `main()` is fire-and-forget: the app NEVER hard-crashes when the
/// emulator suite is unavailable — it boots into [BootstrapStatus.degraded]
/// and retries silently.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:driverapp/core/notifications/push_tap_router.dart';
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

  /// Firebase is initialized and wired; the app is signed OUT. A driver
  /// session arrives later through `bindDeviceToVan` (CHG-0003).
  const factory BootstrapStatus.ready({String? uid}) = BootstrapReady;

  /// Firebase/emulator unavailable: app keeps working locally and retries
  /// silently. A later success upgrades the state to [BootstrapReady].
  const factory BootstrapStatus.degraded({Object? error}) = BootstrapDegraded;
}

final class BootstrapPending extends BootstrapStatus {
  const BootstrapPending();
}

final class BootstrapReady extends BootstrapStatus {
  const BootstrapReady({this.uid});

  /// The Auth uid when a session survived the relaunch, else null.
  final String? uid;
}

final class BootstrapDegraded extends BootstrapStatus {
  const BootstrapDegraded({this.error});

  final Object? error;
}

/// Boot status observable/awaitable by the app (Ticket 02).
final bootstrapProvider = NotifierProvider<BootstrapController, BootstrapStatus>(
  BootstrapController.new,
);

/// How long a gated first lookup waits for boot wiring before proceeding
/// (issue #18): a boot that never resolves must not hang the screen.
const Duration sessionGateCap = Duration(seconds: 8);

/// Gate for the first callable/Firestore use (issue #18, re-scoped by
/// CHG-0003).
///
/// The start-shift flow calls `bindDeviceToVan` and then reads Firestore, so
/// it must not race `Firebase.initializeApp`. This future resolves when the
/// boot has Firebase up (or the boot has a first verdict: the caller proceeds
/// and surfaces its own failure), capped by [sessionGateCap].
///
/// Immediate when boot wiring was never started (unit-test containers), so
/// existing suites are unaffected; override to script the race.
final sessionGateProvider = Provider<Future<void>>((ref) {
  final boot = ref.read(bootstrapProvider.notifier);
  if (!boot.bootStarted) return Future<void>.value();
  return boot.sessionReady().timeout(sessionGateCap, onTimeout: () {});
});

/// Holds the boot state; `main()` starts [run], the app can watch
/// [bootstrapProvider] or await the controller's [done] future.
// Not `final`: tests extend this controller to simulate a degraded boot
// without touching platform channels.
class BootstrapController extends Notifier<BootstrapStatus> {
  Completer<BootstrapStatus>? _done;

  /// Completes the first time Firebase is initialized and its endpoints are
  /// wired (issue #18, re-scoped by CHG-0003): the start-shift flow gates its
  /// bind call and its first read on [sessionReady] so neither races boot.
  Completer<void>? _sessionReady;

  @override
  BootstrapStatus build() => const BootstrapStatus.pending();

  /// True once [run] started the boot wiring (the real app's `main()`);
  /// false in unit-test containers, where [sessionGateProvider] resolves
  /// immediately instead of waiting for a session that will never come.
  bool get bootStarted => _running;

  /// Completes when Firebase is up; immediately when this container is
  /// already [BootstrapReady] (a warm boot).
  Future<void> sessionReady() {
    if (state is BootstrapReady) return Future<void>.value();
    return (_sessionReady ??= Completer<void>()).future;
  }

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
        state = BootstrapStatus.ready(uid: progress.uid);
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

  /// FCM gateway; production uses [FirebaseMessagingGateway].
  @visibleForTesting
  MessagingGateway messagingGateway = const FirebaseMessagingGateway();

  Future<void> _runOnce(_BootProgress progress, FirebaseBackend backend) async {
    // 1. Local flag storage (first-launch detection).
    progress.flagBox ??= await openFlagBox();
    // 2. Firebase core — with the two-engine "already exists" adopt fix
    //    (see [_initializeFirebaseApp]).
    progress.app ??= await _initializeFirebaseApp(backend);
    // A relaunch keeps Firebase Auth's persisted session: report it, and let
    // the start-shift flow re-bind if the token is old (CHG-0003).
    progress.uid ??= FirebaseAuth.instanceFor(app: progress.app!).currentUser?.uid;
    // 3. Emulator wiring (before any Firestore/Auth/Functions use).
    if (!progress.emulatorsWired && backend == FirebaseBackend.emulatorSuite) {
      _wireEmulators(progress.app!);
      progress.emulatorsWired = true;
    }
    // Release the first-use gate (issue #18) the moment Firebase is up: the
    // start-shift flow binds and reads after this, never before.
    final session = _sessionReady;
    if (session != null && !session.isCompleted) session.complete();
    // 4. FCM: init + one-time topic `all` subscription.
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
  String? uid;
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
  // `.run()` never throws; it only degrades internally.
  //
  // The drain starts the moment the boot is (or becomes) READY. Awaiting
  // `run()` here would block forever on a degraded boot (its retry loop is
  // endless), so the drain never started at all in that case; the listener
  // also covers a degraded boot that recovers on a later retry (issue #21).
  // The drain start is idempotent; a host without platform channels
  // (tests, CLI) just logs and boots on (ticket 02 rule).
  unawaited(container.read(bootstrapProvider.notifier).run());
  container.listen<BootstrapStatus>(
    bootstrapProvider,
    (previous, next) {
      if (next is! BootstrapReady) return;
      try {
        container.read(offlineSyncServiceProvider).start();
      } catch (error) {
        debugPrint('bootstrap: offline sync service not started: $error');
      }
      // B-21: only now can FirebaseMessaging be touched safely. The router
      // holds a tap until a shift session exists, so a cold-launch tap is
      // not lost.
      try {
        container.read(pushTapRouterProvider).start();
      } catch (error) {
        debugPrint('bootstrap: push tap router not started: $error');
      }
    },
    fireImmediately: true,
  );
}

/// Silent-retry backoff, `attempt` is 1-based. Cheap calls first so a
/// missing emulator fails fast locally, but a flaky network on the road
/// still gets retried forever without spamming.
Duration bootstrapRetryDelay(int attempt) =>
    Duration(seconds: switch (attempt) { 1 => 2, 2 => 10, _ => 30 });

// ---------------------------------------------------------------------------
// Emulator wiring
// ---------------------------------------------------------------------------

/// Points Firestore/Auth/Functions at the local Emulator Suite (Ticket 02,
/// PRD-2 0.10). Ports 8080 (Firestore), 9099 (Auth) and 5001 (Functions) per
/// Ticket 02; host via [kFirebaseEmulatorHost].
///
/// Cloud Functions joins the same suite: the driver app calls the platform's
/// session and shift callables, so the Functions emulator has to be reachable
/// on the same host as Firestore and Auth.
void _wireEmulators(FirebaseApp app) {
  FirebaseFirestore.instanceFor(app: app)
      .useFirestoreEmulator(kFirebaseEmulatorHost, kFirestoreEmulatorPort);
  FirebaseAuth.instanceFor(app: app)
      .useAuthEmulator(kFirebaseEmulatorHost, kAuthEmulatorPort);
  FirebaseFunctions.instanceFor(app: app)
      .useFunctionsEmulator(kFirebaseEmulatorHost, kFunctionsEmulatorPort);
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

  /// Removes this install from an FCM topic. The shift topic's cleanup rule
  /// (`topics.json`: `van_{vanId}`) requires this on shift end.
  Future<void> unsubscribeFromTopic(String topic);
}

/// Real gateway (production runs).
final class FirebaseMessagingGateway implements MessagingGateway {
  const FirebaseMessagingGateway();

  @override
  Future<void> init() => FirebaseMessaging.instance.setAutoInitEnabled(true);

  @override
  Future<void> subscribeToTopic(String topic) =>
      FirebaseMessaging.instance.subscribeToTopic(topic);

  @override
  Future<void> unsubscribeFromTopic(String topic) =>
      FirebaseMessaging.instance.unsubscribeFromTopic(topic);
}

/// No-op double used by tests (and safe as a degraded fallback).
final class NoopMessagingGateway implements MessagingGateway {
  const NoopMessagingGateway();

  @override
  Future<void> init() async {}

  @override
  Future<void> subscribeToTopic(String topic) async {}

  @override
  Future<void> unsubscribeFromTopic(String topic) async {}
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
