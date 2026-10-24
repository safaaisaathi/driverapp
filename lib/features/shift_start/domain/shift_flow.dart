/// D1 Shift Start flow controller (F-D1, ticket 04).
///
/// One Riverpod notifier drives the whole D1 state machine:
/// van list (loading / empty / error) → van pick → PIN verify (wrong pin /
/// lockout, all localized in the UI layer) → Start or **Resume** shift
/// (grilled decision: reattach the existing trip, never duplicate) →
/// `onShift`, which navigates to the route placeholder.
///
/// All data goes through the repositories (0.11) and the F-D1 data seams
/// ([DriverPinVerifier], [DriverAuthGateway]); the background tracking
/// engine is NOT started here — this only sets the native shift-active
/// state ([ShiftSession]) that ticket 05 hooks into.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/ist_clock.dart';
import '../../../core/models/models.dart';
import '../../../core/repositories/repositories.dart';
import '../data/verify_driver_pin.dart'
    show
        DriverPinFailureKind,
        DriverPinException,
        DriverPinVerifier,
        DriverAuthGateway,
        pinVerifierProvider,
        driverAuthGatewayProvider,
        driverMessagingGatewayProvider,
        fcmTopicVanOf;
import '../../../core/config/firebase_bootstrap.dart' show MessagingGateway;
import 'shift_session.dart';

/// One row of the van picker: the public `vans` doc plus its resolved
/// route name (`vans.routeId` → `routes`, spec story 4).
final class VanPickerEntry {
  const VanPickerEntry({required this.van, required this.routeName});

  final Van van;

  /// Resolved `routes.name`; `null` when the route read failed (pickers
  /// still selectable — the UI shows a localized "route not set" line).
  final String? routeName;
}

enum ShiftFlowPhase {
  /// Van list loading.
  loadingVans,

  /// Van list read failed (emulator/instance down) — error + retry state.
  vanListFailed,

  /// Van list present. No van picked yet, or picked with PIN entry.
  pickVan,

  /// PIN verification/sign-in in flight.
  verifyingPin,

  /// Signed in with the custom token; Start/Resume button ready.
  readyToStart,

  /// Trip writes in flight.
  startingShift,

  /// Shift is running (fresh trip created or existing one reattached).
  onShift,
}

/// The failure showing on D1 (messages localized in the UI, never raw
/// backend text — 0.11).
enum ShiftFlowFailure { wrongPin, lockedOut, verifyUnavailable, startFailed }

/// Immutable D1 state.
final class ShiftFlowState {
  const ShiftFlowState({
    required this.phase,
    this.vans = const <VanPickerEntry>[],
    this.selectedVanId,
    this.resumable = false,
    this.failure,
    this.session,
  });

  final ShiftFlowPhase phase;

  /// The van list (once loaded).
  final List<VanPickerEntry> vans;

  /// The currently picked van doc id, inside `vans` (or `null`).
  final String? selectedVanId;

  /// True when the picked van already has an open shift
  /// (`currentTripId != null && status == on_shift`) — the button becomes
  /// **Resume shift** and taps reattach instead of creating a trip.
  final bool resumable;

  /// The failure the active screen shows (wrong PIN, lockout, outages,
  /// failed shift writes). Cleared on the next attempt.
  final ShiftFlowFailure? failure;

  /// The running shift once [ShiftFlowPhase.onShift].
  final ShiftSession? session;

  VanPickerEntry? get selectedVan {
    final id = selectedVanId;
    if (id == null) return null;
    for (final entry in vans) {
      if (entry.van.id == id) return entry;
    }
    return null;
  }

  ShiftFlowState copyWith({
    ShiftFlowPhase? phase,
    List<VanPickerEntry>? vans,
    String? selectedVanId,
    bool? resumable,
    ShiftFlowFailure? failure,
    ShiftSession? session,
  }) =>
      ShiftFlowState(
        phase: phase ?? this.phase,
        vans: vans ?? this.vans,
        selectedVanId: selectedVanId ?? this.selectedVanId,
        resumable: resumable ?? this.resumable,
        failure: failure ?? this.failure,
        session: session ?? this.session,
      );

  /// Drop-only variants (nullable fields cannot use `??` copyWith).
  ShiftFlowState clearSelection() => ShiftFlowState(
        phase: phase,
        vans: vans,
        selectedVanId: null,
        resumable: false,
        failure: null,
        session: session,
      );

  ShiftFlowState clearFailure() => ShiftFlowState(
        phase: phase,
        vans: vans,
        selectedVanId: selectedVanId,
        resumable: resumable,
        failure: null,
        session: session,
      );
}

/// Riverpod wiring for the D1 flow.
final shiftStartFlowProvider =
    NotifierProvider<ShiftStartFlowController, ShiftFlowState>(
  ShiftStartFlowController.new,
);

/// Drives D1 (public methods = events from the screen).
// Not `final`: tests may subclass to script edge cases.
class ShiftStartFlowController extends Notifier<ShiftFlowState> {
  @override
  ShiftFlowState build() => const ShiftFlowState(
        phase: ShiftFlowPhase.loadingVans,
      );

  VansRepository get _vans =>
      ref.watch(vansRepositoryProvider);

  TripsRepository get _trips => ref.watch(tripsRepositoryProvider);

  RoutesRepository get _routes => ref.watch(routesRepositoryProvider);

  DriverPinVerifier get _pinVerifier => ref.watch(pinVerifierProvider);

  DriverAuthGateway get _auth => ref.watch(driverAuthGatewayProvider);

  MessagingGateway get _messaging => ref.watch(driverMessagingGatewayProvider);

  /// Loads the van list + route names; retryable from the error state.
  Future<void> loadVans() async {
    _initialLoadRun = true;
    state = const ShiftFlowState(phase: ShiftFlowPhase.loadingVans);
    try {
      final vans = await _vans.readVans();
      final entries = await Future.wait(vans.map(_resolveEntry));
      state = ShiftFlowState(
        phase: ShiftFlowPhase.pickVan,
        vans: List.unmodifiable(entries),
      );
    } on Exception {
      state = const ShiftFlowState(phase: ShiftFlowPhase.vanListFailed);
    }
  }

  Future<VanPickerEntry> _resolveEntry(Van van) async {
    String? routeName;
    try {
      routeName = (await _routes.readRoute(van.routeId))?.name;
    } on Exception {
      // Route read is best-effort: the van stays pickable and the UI
      // shows a localized "route not set" line (never blocked by one doc).
    }
    return VanPickerEntry(van: van, routeName: routeName);
  }

  /// Van tapped in the picker; the PIN entry focuses (UI decision).
  void selectVan(String vanId) {
    state = state
        .copyWith(selectedVanId: vanId, phase: ShiftFlowPhase.pickVan)
        .clearFailure();
  }

  /// Verifies the PIN (callable) and signs in with the custom token.
  /// Wrong PIN / lockout surface as localized failure flags, never crash.
  Future<void> submitPin(String pin) async {
    // ignore: avoid_print
    print('FLOW submitPin enter pin=$pin');
    final selected = state.selectedVan;
    if (selected == null || pin.length != 4) return;
    // ignore: avoid_print
    print('FLOW submitPin guard-pass');
    state = state
        .copyWith(phase: ShiftFlowPhase.verifyingPin)
        .clearFailure();
    try {
      final token =
          await _pinVerifier.verifyPin(vanId: selected.van.id, pin: pin);
      // ignore: avoid_print
      print('FLOW verifier returned token=$token');
      await _auth.signInWithCustomToken(token);
      // ignore: avoid_print
      print('FLOW auth returned');
      // Refresh the van snapshot: it may already hold an open shift from
      // an earlier session — that picks the Resume branch later.
      // ignore: avoid_print
      print('FLOW before latestVan');
      final fresh = await _latestVan(selected.van.id);
      // ignore: avoid_print
      print('FLOW latestVan got ${fresh?.id}');
      if (fresh == null) {
        state = state.copyWith(
          phase: ShiftFlowPhase.pickVan,
          failure: ShiftFlowFailure.startFailed,
        );
        return;
      }
      final resumable = _isResumable(fresh);
      state = state.copyWith(
        phase: ShiftFlowPhase.readyToStart,
        vans: _replaceVan(fresh),
        resumable: resumable,
      );
      // ignore: avoid_print
      print('FLOW readyToStart set');
    } on DriverPinException catch (pinError) {
      // ignore: avoid_print
      print('FLOW DriverPinException ${pinError.kind}');
      state = state.copyWith(
        phase: ShiftFlowPhase.pickVan,
        failure: switch (pinError.kind) {
          DriverPinFailureKind.wrongPin => ShiftFlowFailure.wrongPin,
          DriverPinFailureKind.lockedOut => ShiftFlowFailure.lockedOut,
          DriverPinFailureKind.unavailable =>
            ShiftFlowFailure.verifyUnavailable,
        },
      );
    } on Exception {
      // ignore: avoid_print
      print('FLOW generic Exception in submitPin');
      state = state.copyWith(
        phase: ShiftFlowPhase.pickVan,
        failure: ShiftFlowFailure.verifyUnavailable,
      );
    }
  }

  /// Start Shift (or Resume shift on the grilled resume branch).
  ///
  /// Fresh: creates the 0.2 `trips` doc (vanId, routeId from the van,
  /// date = today IST, startedAt), sets `vans.status = on_shift` and
  /// `vans.currentTripId`, subscribes to topic `van_{vanId}`.
  /// Resume: reattaches the existing trip doc — a second `createTrip`
  /// is never issued. Write failures surface as [ShiftFlowFailure.startFailed].
  Future<void> startShift() async {
    final selected = state.selectedVan;
    if (selected == null) return;
    state = state
        .copyWith(phase: ShiftFlowPhase.startingShift)
        .clearFailure();
    try {
      final now = DateTime.now();
      final van = await _latestVan(selected.van.id);
      if (van == null) {
        throw StateError('Van doc disappeared while starting the shift');
      }

      final ShiftSession session;
      if (_isResumable(van)) {
        // Grilled decision: RESUME, never duplicate. Reattach to the
        // existing trip; no trip doc is written.
        session = await _resumeSession(van, now);
      } else {
        session = await _createTripAndMarkVan(van, now);
      }
      ref.read(shiftControllerProvider.notifier).activate(session);
      await _subscribeVanTopic(session.vanId);
      state = state.copyWith(
        phase: ShiftFlowPhase.onShift,
        session: session,
      );
    } on Exception {
      state = state.copyWith(
        phase: ShiftFlowPhase.readyToStart,
        failure: ShiftFlowFailure.startFailed,
      );
    }
  }

  /// Screen entry point (idempotent): the D1 widget calls this once.
  Future<void> ensureVansLoaded() async {
    if (_initialLoadRun) return;
    await loadVans();
  }

  bool _initialLoadRun = false;

  /// Retry entry point for the error states (van list, start writes).
  Future<void> retry() async {
    if (state.phase == ShiftFlowPhase.vanListFailed) {
      await loadVans();
    } else if (state.failure == ShiftFlowFailure.startFailed) {
      await startShift();
    } else if (state.failure == ShiftFlowFailure.verifyUnavailable) {
      await loadVans();
    }
  }

  /// Called after the successful-start navigation: returns the flow to the
  /// picker view (vans kept) so a pop back to D1 lands sensibly, while the
  /// shift itself keeps running in [shiftControllerProvider].
  void clearNavigated() {
    if (state.phase != ShiftFlowPhase.onShift) return;
    state = ShiftFlowState(
      phase: ShiftFlowPhase.pickVan,
      vans: state.vans,
    );
  }

  // -- internals --

  bool _isResumable(Van van) =>
      van.currentTripId != null && van.status == VanStatus.onShift;

  Future<Van?> _latestVan(String vanId) => _vans.watchVan(vanId).first;

  /// Fresh start (0.13 behaviour rules 3): trip doc + van marker writes,
  /// in that order, each through its repository.
  Future<ShiftSession> _createTripAndMarkVan(Van van, DateTime now) async {
    // `date` = the collection-day calendar date resolved in IST
    // (grilled ruling, spec Implementation Decisions).
    final date = utcStartOfIstDay(now);
    // `startedAt`: models carry DateTime only (Ticket 01 seam) — client
    // clock is used; server-timestamp support is a tracked gap note.
    final startedAt = now;
    final trip = Trip(
      id: '',
      vanId: van.id,
      routeId: van.routeId,
      date: date,
      startedAt: startedAt,
      endedAt: null,
      wardsDone: const <WardDone>[],
      alertedWardIds: const <String>[],
      gpsTrail: const <GpsPoint>[],
      mockLocationDetected: false,
    );
    final created = await _trips.createTrip(trip);
    await _vans.updateStatus(van.id, VanStatus.onShift);
    await _vans.updateCurrentTripId(van.id, created.id);
    return ShiftSession(
      vanId: van.id,
      tripId: created.id,
      routeId: van.routeId,
      startedAt: created.startedAt,
      date: created.date,
    );
  }

  /// Resume branch: the existing trip's identity comes back untouched.
  Future<ShiftSession> _resumeSession(Van van, DateTime now) async {
    final tripId = van.currentTripId!;
    final date = utcStartOfIstDay(now);
    final todayTrip = await _trips
        .watchTripByVanIdAndDate(vanId: van.id, date: date)
        .first;
    final startedAt = todayTrip != null && todayTrip.id == tripId
        ? todayTrip.startedAt
        // Edge (trip from an earlier IST day left open): keep going with
        // the local clock estimate — never block the driver.
        : now;
    return ShiftSession(
      vanId: van.id,
      tripId: tripId,
      routeId: van.routeId,
      startedAt: startedAt,
      date: todayTrip?.date ?? date,
    );
  }

  /// Topic `van_{vanId}` (PRD-2 0.6.6) — best effort: an FCM outage must
  /// not fail the started shift (bootstrap retries the suite itself).
  Future<void> _subscribeVanTopic(String vanId) async {
    try {
      await _messaging.subscribeToTopic(fcmTopicVanOf(vanId));
    } on Exception {
      // Silent degrade; the notice push path is a demo nicety here.
    }
  }

  List<VanPickerEntry> _replaceVan(Van fresh) => [
        for (final entry in state.vans)
          if (entry.van.id == fresh.id)
            VanPickerEntry(van: fresh, routeName: entry.routeName)
          else
            entry,
      ];
}
