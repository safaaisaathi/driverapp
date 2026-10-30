/// Driver-identity start-shift flow controller (ticket 4, PRD-2 §0.16).
///
/// One Riverpod notifier drives the NEW start-shift slice: code entry →
/// (inline format error BEFORE any lookup) → lookup through the
/// [DriversRepository] seam → confirm card ([IdentityFlowPhase.confirmReady],
/// which also remembers the code on-device) → Start Shift (trip created
/// from the driver's van through [StartShift], session activated) →
/// `onShift`, which navigates to the live route.
///
/// Distinct failure phases with retry: [IdentityFlowPhase.invalidCode]
/// (format, no lookup), [IdentityFlowPhase.notFound] (unknown OR inactive
/// — the seam returns inactive docs, the flow treats them as not-found),
/// [IdentityFlowPhase.lookupFailed] (offline/outage) and
/// [IdentityFlowPhase.startFailed] (write failure). The background
/// tracking engine is NOT started here — the screen hands the session to
/// the tracking auto-start after activation, same as the old D1 screen.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/firebase_bootstrap.dart'
    show MessagingGateway, sessionGateProvider;
import '../../../core/identity/driver_identity_controller.dart';
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
  /// lookup call was made (0.16: a bad shape never reaches Firestore).
  invalidCode,

  /// Lookup in flight.
  lookingUp,

  /// Driver found and active: the confirm card shows name, van, ward
  /// count and masked phone. The code is remembered on-device on entry.
  confirmReady,

  /// Unknown code, or the doc exists with `active = false`. Retry.
  notFound,

  /// The lookup itself failed (offline / outage). Retry.
  lookupFailed,

  /// Start Shift writes in flight (trip + van marker).
  starting,

  /// Shift is running (session activated; the screen navigates away).
  onShift,

  /// The start writes failed; the confirm card stays with an error line.
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
    this.lastRawCode,
    this.session,
  });

  final IdentityFlowPhase phase;

  /// The confirmed driver doc (confirm card content). Null outside the
  /// confirm/starting/onShift/startFailed phases.
  final Driver? driver;

  /// The allotted van's plate (`vans/{driver.vanId}.plateNo`), resolved at
  /// lookup time for the confirm card. Null when the van doc is missing
  /// (the card then falls back to the raw van id in the UI).
  final String? vanPlate;

  /// The code as the driver typed it (normalized on submit); the retry of
  /// notFound/lookupFailed re-looks-up this.
  final String? lastRawCode;

  /// The running shift once [IdentityFlowPhase.onShift].
  final ShiftSession? session;

  IdentityFlowState copyWith({
    IdentityFlowPhase? phase,
    Driver? driver,
    String? vanPlate,
    String? lastRawCode,
    ShiftSession? session,
  }) =>
      IdentityFlowState(
        phase: phase ?? this.phase,
        driver: driver ?? this.driver,
        vanPlate: vanPlate ?? this.vanPlate,
        lastRawCode: lastRawCode ?? this.lastRawCode,
        session: session ?? this.session,
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

  TripsRepository get _trips => ref.read(tripsRepositoryProvider);

  MessagingGateway get _messaging => ref.read(driverMessagingGatewayProvider);

  StartShift get _startShift =>
      StartShift(trips: _trips, vans: _vans, messaging: _messaging);

  /// Continue tapped on the code field. Normalizes first: a bad shape
  /// lands on [IdentityFlowPhase.invalidCode] and makes NO lookup call
  /// (0.16). A found-but-inactive driver is [IdentityFlowPhase.notFound]
  /// (flow rule; the seam itself does no active-filtering).
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
    // Issue #18: on a cold launch the anonymous session may still be signing
    // in; the FIRST read must not race it, or it fails unauthenticated on
    // every launch (the "Couldn't check the code" welcome bug). Immediate in
    // unit tests and on a warm boot.
    await ref.read(sessionGateProvider);
    try {
      final driver = await _drivers.fetchDriver(code);
      if (driver == null || !driver.active) {
        state = state.copyWith(
          phase: IdentityFlowPhase.notFound,
          lastRawCode: raw,
        );
        return;
      }
      // The van doc backs the confirm card's plate and the Start action;
      // a failed read is an outage, not a not-found.
      final van = await _vans.readVan(driver.vanId);
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
        lastRawCode: raw,
      );
    } on Exception {
      state = state.copyWith(
        phase: IdentityFlowPhase.lookupFailed,
        lastRawCode: raw,
      );
    }
  }

  /// Start Shift on the confirm card: creates the trip from the driver's
  /// van (via the extracted [StartShift] core), activates the shift
  /// session, subscribes the van topic, and lands on
  /// [IdentityFlowPhase.onShift]. Write failures keep the confirm data on
  /// [IdentityFlowPhase.startFailed].
  Future<void> start() async {
    final driver = state.driver;
    final startable = state.phase == IdentityFlowPhase.confirmReady ||
        state.phase == IdentityFlowPhase.startFailed;
    if (driver == null || !startable) return;
    state = state.copyWith(phase: IdentityFlowPhase.starting);
    try {
      final van = await _vans.readVan(driver.vanId);
      if (van == null) {
        state = state.copyWith(phase: IdentityFlowPhase.startFailed);
        return;
      }
      final session = await _startShift.execute(van, driver, DateTime.now());
      ref.read(shiftControllerProvider.notifier).activate(session);
      state = state.copyWith(
        phase: IdentityFlowPhase.onShift,
        session: session,
      );
    } on Exception {
      state = state.copyWith(phase: IdentityFlowPhase.startFailed);
    }
  }

  /// Retry entry point for the three failure states: not-found and
  /// lookup-failed re-look-up the last entered code; start-failure re-runs
  /// the start.
  Future<void> retry() async {
    switch (state.phase) {
      case IdentityFlowPhase.notFound:
      case IdentityFlowPhase.lookupFailed:
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
}
