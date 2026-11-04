/// Driver-identity start-shift flow controller (ticket 4, PRD-2 §0.16,
/// CHG-0003).
///
/// One Riverpod notifier drives the new start-shift slice: code entry →
/// (inline format error BEFORE any call) → `bindDeviceToVan` + custom-token
/// sign-in → lookup through the [DriversRepository] seam → confirm card
/// ([IdentityFlowPhase.confirmReady], which also remembers the code
/// on-device) → Start Shift (the `startShift` callable, then a fresh token
/// carrying `currentTripId`, session activated) → `onShift`, which navigates
/// to the live route.
///
/// The sign-in moved INTO the lookup (CHG-0003): the driver's reads are
/// scoped by the `driverId` claim, so `drivers/{code}` and `vans/{vanId}`
/// cannot be read before the bind. The screen is unchanged; only the order of
/// the data path changed.
///
/// Distinct failure phases with retry: [IdentityFlowPhase.invalidCode]
/// (format, no call), [IdentityFlowPhase.notFound] (unknown OR inactive),
/// [IdentityFlowPhase.lookupFailed] (offline/outage),
/// [IdentityFlowPhase.accessFailed] (the bind refused: another phone holds
/// the van, too many attempts, or the session is not allowed — the reason is
/// on [IdentityFlowState.reason]) and [IdentityFlowPhase.startFailed] (the
/// start call refused or failed). The background tracking engine is NOT
/// started here — the screen hands the session to the tracking auto-start
/// after activation, same as the old D1 screen.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/firebase_bootstrap.dart'
    show MessagingGateway, sessionGateProvider;
import '../../../core/contract/gateway_providers.dart';
import '../../../core/contract/reason_codes.dart';
import '../../../core/contract/shift_gateway.dart';
import '../../../core/identity/driver_identity_controller.dart';
import '../../../core/identity/install_id.dart';
import '../../../core/models/models.dart';
import '../../../core/repositories/repositories.dart';
import '../data/fcm_topics.dart' show driverMessagingGatewayProvider;
import 'shift_session.dart';
import 'start_shift.dart';

/// The phases of the new start-shift page (0.16). Every failure phase is
/// retryable through [IdentityFlowController.retry].
enum IdentityFlowPhase {
  /// Code entry, nothing submitted yet.
  initial,

  /// The entered text has no valid `XX-0000` shape — inline error, and NO
  /// call was made (0.16: a bad shape never reaches the platform).
  invalidCode,

  /// Bind + lookup in flight.
  lookingUp,

  /// Driver found and active: the confirm card shows name, van, ward
  /// count and masked phone. The code is remembered on-device on entry.
  confirmReady,

  /// Unknown code, or the doc exists with `active = false`. Retry.
  notFound,

  /// The bind or the lookup itself failed (offline / outage). Retry.
  lookupFailed,

  /// The bind was refused with a contract code (another phone holds the van,
  /// too many attempts, not authorised). The code is on
  /// [IdentityFlowState.reason]; Retry re-attempts the bind.
  accessFailed,

  /// Start Shift call in flight.
  starting,

  /// Shift is running (session activated; the screen navigates away).
  onShift,

  /// The start call failed; the confirm card stays with an error line.
  /// Retry re-runs the start.
  startFailed,
}

/// Immutable flow state. The confirm data (driver, plate) and the last
/// entered code survive into the failure phases so the UI can keep the
/// card/error context and retry without re-typing.
final class IdentityFlowState {
  const IdentityFlowState({
    required this.phase,
    this.driver,
    this.vanPlate,
    this.routeName,
    this.lastRawCode,
    this.session,
    this.reason,
  });

  final IdentityFlowPhase phase;

  /// The confirmed driver doc (confirm card content). Null outside the
  /// confirm/starting/onShift/startFailed phases.
  final Driver? driver;

  /// The allotted van's plate (`vans/{driver.vanId}.plateNo`), resolved at
  /// lookup time for the confirm card. Null when the van doc is missing
  /// (the card then falls back to the raw van id in the UI).
  final String? vanPlate;

  /// The allotted route's name (`routes/{driver.routeId}.name`), resolved
  /// at lookup time for the welcome-back card's Route row (ruling #28).
  /// Null when the route doc is missing or unreadable: the row then falls
  /// back to the raw route id, never blocks the lookup.
  final String? routeName;

  /// The code as the driver typed it (normalized on submit); the retry of
  /// notFound/lookupFailed re-looks-up this.
  final String? lastRawCode;

  /// The running shift once [IdentityFlowPhase.onShift].
  final ShiftSession? session;

  /// Why the last call was refused ([IdentityFlowPhase.accessFailed] and
  /// [IdentityFlowPhase.startFailed]). The UI picks the localized words from
  /// this code; a raw code is never shown to the driver.
  final ReasonCode? reason;

  IdentityFlowState copyWith({
    IdentityFlowPhase? phase,
    Driver? driver,
    String? vanPlate,
    String? routeName,
    String? lastRawCode,
    ShiftSession? session,
    ReasonCode? reason,
  }) =>
      IdentityFlowState(
        phase: phase ?? this.phase,
        driver: driver ?? this.driver,
        vanPlate: vanPlate ?? this.vanPlate,
        routeName: routeName ?? this.routeName,
        lastRawCode: lastRawCode ?? this.lastRawCode,
        session: session ?? this.session,
        reason: reason ?? this.reason,
      );
}

/// Riverpod wiring for the new start-shift flow.
final identityFlowProvider =
    NotifierProvider<IdentityFlowController, IdentityFlowState>(
  IdentityFlowController.new,
);

/// Drives the new start-shift page (public methods = events from the
/// screen).
// Not `final`: tests may subclass to script edge cases.
class IdentityFlowController extends Notifier<IdentityFlowState> {
  @override
  IdentityFlowState build() =>
      const IdentityFlowState(phase: IdentityFlowPhase.initial);

  // Imperative reads (not watches): this controller drives clicks and
  // retriable attempts; it must not be rebuilt when a repository provider
  // is (re)created (the ShiftStartFlowController lesson).
  DriversRepository get _drivers => ref.read(driversRepositoryProvider);

  VansRepository get _vans => ref.read(vansRepositoryProvider);

  RoutesRepository get _routes => ref.read(routesRepositoryProvider);

  DriverSessionGateway get _session => ref.read(driverSessionGatewayProvider);

  MessagingGateway get _messaging => ref.read(driverMessagingGatewayProvider);

  StartShift get _startShift => StartShift(
        gateway: ref.read(shiftGatewayProvider),
        session: _session,
        messaging: _messaging,
      );

  /// Continue tapped on the code field. Normalizes first: a bad shape
  /// lands on [IdentityFlowPhase.invalidCode] and makes NO call (0.16).
  ///
  /// Then the bind: `bindDeviceToVan({driverCode, installId})` mints the
  /// custom token, the app signs in with it, and only then may it read the
  /// driver/van/route docs (the claims scope those reads). A found-but-
  /// inactive driver is [IdentityFlowPhase.notFound].
  Future<void> submitCode(String raw) async {
    if (state.phase == IdentityFlowPhase.lookingUp) return;
    final code = normalizeDriverCode(raw);
    if (code == null) {
      state = const IdentityFlowState(phase: IdentityFlowPhase.invalidCode);
      return;
    }
    // copyWith (issue #19): the confirm data survives into the failure
    // phases, exactly as the state contract documents, so a failed retry
    // keeps the driver's name on the welcome card.
    state = state.copyWith(
      phase: IdentityFlowPhase.lookingUp,
      lastRawCode: raw,
    );
    // Issue #18: on a cold launch Firebase may still be initializing; the
    // bind callable and the read must not race it. Immediate in unit tests.
    await ref.read(sessionGateProvider);
    try {
      final installId = await ref.read(installIdStoreProvider).readOrCreate();
      final binding = await _session.bindDeviceToVan(
        driverCode: code,
        installId: installId,
      );
      await _session.signInWithCustomToken(binding.token);
    } on ContractException catch (error) {
      state = state.copyWith(
        phase: _isLookupFailure(error.code)
            ? IdentityFlowPhase.lookupFailed
            : IdentityFlowPhase.accessFailed,
        lastRawCode: raw,
        reason: error.code,
      );
      return;
    } on Exception catch (error) {
      _traceLookupFailure(code, error);
      state = state.copyWith(
        phase: IdentityFlowPhase.lookupFailed,
        lastRawCode: raw,
      );
      return;
    }
    try {
      final driver = await _drivers.fetchDriver(code);
      if (driver == null || !driver.active) {
        state = state.copyWith(
          phase: IdentityFlowPhase.notFound,
          lastRawCode: raw,
        );
        return;
      }
      // The van doc backs the confirm card's plate; a failed read is an
      // outage, not a not-found.
      final van = await _vans.readVan(driver.vanId);
      // The route doc backs the welcome card's Route row (#28). A missing or
      // unreadable route is NOT a lookup failure: the row falls back to the
      // raw route id, and a driver must never be locked out by admin data.
      String? routeName;
      try {
        routeName = (await _routes.readRoute(driver.routeId))?.name;
      } on Exception {
        routeName = null;
      }
      // The identity is confirmed the moment the confirm card appears:
      // remember the code on-device (0.16 "after the first confirm the
      // code is remembered"). rememberDriver never throws.
      await ref
          .read(driverIdentityControllerProvider.notifier)
          .rememberDriver(code);
      state = IdentityFlowState(
        phase: IdentityFlowPhase.confirmReady,
        driver: driver,
        vanPlate: van?.plateNo,
        routeName: routeName,
        lastRawCode: raw,
      );
    } on Exception catch (error) {
      // The trace that was missing when the cold-start failure had to be
      // reverse-engineered (issue #21). Debug-only, per the AVV rule.
      _traceLookupFailure(code, error);
      state = state.copyWith(
        phase: IdentityFlowPhase.lookupFailed,
        lastRawCode: raw,
      );
    }
  }

  /// Start Shift on the confirm card: the `startShift` callable creates (or
  /// resumes) the trip server-side and returns a token with
  /// `currentTripId`; the app signs in with it, activates the shift session,
  /// subscribes the van topic, and lands on [IdentityFlowPhase.onShift].
  /// Refusals keep the confirm data on [IdentityFlowPhase.startFailed].
  Future<void> start() async {
    final driver = state.driver;
    final startable = state.phase == IdentityFlowPhase.confirmReady ||
        state.phase == IdentityFlowPhase.startFailed;
    if (driver == null || !startable) return;
    state = state.copyWith(phase: IdentityFlowPhase.starting);
    try {
      final session = await _startShift.execute(driver, DateTime.now());
      ref.read(shiftControllerProvider.notifier).activate(session);
      state = state.copyWith(
        phase: IdentityFlowPhase.onShift,
        session: session,
      );
    } on ContractException catch (error) {
      state = state.copyWith(
        phase: IdentityFlowPhase.startFailed,
        reason: error.code,
      );
    } on Exception {
      state = state.copyWith(phase: IdentityFlowPhase.startFailed);
    }
  }

  /// Launch-time resume (ruling #27): when the confirmed driver's van still
  /// holds an open shift that belongs to them, reattach it WITHOUT a tap —
  /// the screen then treats the flow like a normal [IdentityFlowPhase.onShift]
  /// and navigates straight to the live route with tracking started.
  ///
  /// Returns the session when resumed. Returns `null` (and leaves the flow
  /// where it is, so the welcome card keeps its one-tap Start) when:
  /// - the van has no open shift (the driver ended it before leaving),
  /// - the read failed (offline launch: the card must still render).
  ///
  /// The reattach itself is the server's decision: `startShift` resumes the
  /// open trip and writes nothing. A different driver's shift reaches the
  /// caller as a refusal, never a takeover.
  Future<ShiftSession?> resumeIfActive() async {
    final driver = state.driver;
    if (driver == null) return null;
    if (state.phase == IdentityFlowPhase.onShift) return state.session;
    if (state.phase != IdentityFlowPhase.confirmReady) return null;
    try {
      final van = await _vans.readVan(driver.vanId);
      if (van == null) return null;
      if (!_startShift.isResumable(van)) return null;
      await start();
      return state.phase == IdentityFlowPhase.onShift ? state.session : null;
    } on Exception {
      // An offline read: stay on the welcome card and let the driver's one
      // tap surface the reason.
      return null;
    }
  }

  /// Retry entry point for the failure states: not-found, lookup-failed,
  /// access-failed and start-failure. The first three re-run the bind +
  /// lookup for the last entered code; start-failure re-runs the start.
  Future<void> retry() async {
    switch (state.phase) {
      case IdentityFlowPhase.notFound:
      case IdentityFlowPhase.lookupFailed:
      case IdentityFlowPhase.accessFailed:
        final raw = state.lastRawCode;
        if (raw != null) await submitCode(raw);
      case IdentityFlowPhase.startFailed:
        await start();
      default:
        break; // Retry is meaningless on the other phases.
    }
  }

  /// "Different driver?" on the welcome-back card (ticket 5): drops the
  /// current confirm context back to a resting [IdentityFlowPhase.initial]
  /// entry. The remembered code stays on-device (only a new confirm
  /// overwrites it); a lookup or a start in flight is untouched, and a
  /// running shift is never clobbered.
  void resetToEntry() {
    switch (state.phase) {
      case IdentityFlowPhase.lookingUp:
      case IdentityFlowPhase.starting:
      case IdentityFlowPhase.onShift:
        return; // Never over an in-flight or a running flow.
      default:
        break;
    }
    state = const IdentityFlowState(phase: IdentityFlowPhase.initial);
  }

  /// Called after the successful-start navigation: returns the flow to a
  /// fresh code entry (the shift itself keeps running in
  /// [shiftControllerProvider]).
  void clearNavigated() {
    if (state.phase != IdentityFlowPhase.onShift) return;
    state = const IdentityFlowState(phase: IdentityFlowPhase.initial);
  }

  /// Offline and an unknown transport failure keep the generic "couldn't
  /// check" surface; every other bind refusal is a reason the driver can act
  /// on and gets its own words.
  bool _isLookupFailure(ReasonCode code) =>
      code == ReasonCode.offline ||
      code == ReasonCode.unknown ||
      code == ReasonCode.internal ||
      code == ReasonCode.invalidInput;

  void _traceLookupFailure(String code, Object error) {
    assert(() {
      // ignore: avoid_print
      print('identity lookup failed for $code: $error');
      return true;
    }());
  }
}
