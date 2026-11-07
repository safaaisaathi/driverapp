/// D4 Pending Reports flow controller (F-D6, ticket 10).
///
/// One Riverpod notifier drives the D4 state machine: loading → the list
/// (ready / empty) or the degraded states (error / offline, localized in
/// the UI layer). The list is exactly today's `missed_collection`
/// complaints for the running shift's route wards awaiting driver action
/// — statuses `received` and `assigned` (Glossary: Pending Report).
///
/// The route context comes from the shift session (F-D1 → anywhere seam):
/// `shiftControllerProvider` → `routesRepositoryProvider.readRoute` →
/// `routes.wardIds` in visiting order. All data goes through the
/// repositories (0.11); the driver only ever updates the `status` fields
/// of the tapped complaint — "Will Revisit" → `assigned`, "Done" →
/// `resolved` + `resolvedAt` (0.2 shape; `resolvedPhotoUrl` stays unset —
/// no contract field requires the driver to add one). Writes are always
/// per-complaint (single document update), never a batch.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/firebase_bootstrap.dart'
    show sessionGateProvider;
import '../../../core/domain/ist_clock.dart';
import '../../../core/models/models.dart';
import '../../../core/repositories/repositories.dart';
import '../../shift_start/domain/shift_session.dart';

enum PendingReportsPhase {
  /// First snapshot pending.
  loading,

  /// Reports on screen (this route's wards, today, open statuses).
  ready,

  /// The watch returned nothing — the quiet "nothing pending" state.
  empty,

  /// Read/write failed for reasons other than transport (degraded).
  error,

  /// Transport unavailable (`code == unavailable`) — dead zone / no network.
  offline,
}

/// Immutable D4 state; every string the screen shows comes from l10n.
final class PendingReportsState {
  const PendingReportsState({
    required this.phase,
    this.reports = const <Complaint>[],
    this.actionsInFlight = const <String>{},
  });

  final PendingReportsPhase phase;

  /// The visible reports when [PendingReportsPhase.ready].
  final List<Complaint> reports;

  /// Complaint ids with a write in flight — those rows' buttons disable
  /// so one tap cannot double-write a status.
  final Set<String> actionsInFlight;

  PendingReportsState copyWith({
    PendingReportsPhase? phase,
    List<Complaint>? reports,
    Set<String>? actionsInFlight,
  }) =>
      PendingReportsState(
        phase: phase ?? this.phase,
        reports: reports ?? this.reports,
        actionsInFlight: actionsInFlight ?? this.actionsInFlight,
      );
}

/// Riverpod wiring for the D4 flow.
final pendingReportsFlowProvider =
    NotifierProvider<PendingReportsFlowController, PendingReportsState>(
  PendingReportsFlowController.new,
);

/// Drives D4 (public methods = events from the screen).
// Not `final`: tests may subclass to script edge cases.
class PendingReportsFlowController extends Notifier<PendingReportsState> {
  StreamSubscription<List<Complaint>>? _sub;

  bool _loadInFlight = false;

  @override
  PendingReportsState build() {
    // The route context is the one reactive dependency: activating (or
    // ending) a shift rebuilds this flow; the screen kicks the (re)load
    // post-frame while the phase is loading (the D1 pattern).
    ref.watch(shiftControllerProvider);
    ref.onDispose(() {
      unawaited(_sub?.cancel());
      _sub = null;
    });
    return const PendingReportsState(
      phase: PendingReportsPhase.loading,
    );
  }

  // Imperative reads (not watches): this controller drives clicks and
  // retriable loads; repository providers must not rebuild it (the D1
  // lesson — a rebuild would loop through the loading phase).
  ComplaintsRepository get _complaints =>
      ref.read(complaintsRepositoryProvider);

  RoutesRepository get _routes => ref.read(routesRepositoryProvider);

  /// Screen entry point (the widget calls it while the phase is loading);
  /// a no-op once a watch is active — re-subscription goes through [retry].
  Future<void> ensureLoaded() async {
    if (_sub != null) return;
    await _load();
  }

  /// Retry entry point for the error / offline states.
  Future<void> retry() => _load();

  Future<void> _load() async {
    // Re-entrancy guard: a loading-phase kick landing while a load is in
    // flight must not layer subscriptions.
    if (_loadInFlight) return;
    _loadInFlight = true;
    try {
      await _runLoad();
    } finally {
      _loadInFlight = false;
    }
  }

  Future<void> _runLoad() async {
    final session = ref.read(shiftControllerProvider);
    if (session == null) {
      // D4 without a running shift has no route context (dev/demo misuse);
      // surface the boring degraded state — Retry re-runs the load.
      state = const PendingReportsState(phase: PendingReportsPhase.error);
      return;
    }
    state = const PendingReportsState(phase: PendingReportsPhase.loading);
    try {
      // F-11: the route read is Firestore work; never race boot on a cold or
      // degraded launch.
      await ref.read(sessionGateProvider);
      final route = await _routes.readRoute(session.routeId);
      if (route == null) {
        // A missing route doc invents no wards — degraded state.
        state = const PendingReportsState(
          phase: PendingReportsPhase.error,
        );
        return;
      }
      // Fire-and-forget: awaiting a subscription cancel never completes
      // inside the widget-test FakeAsync zone (the old stream is being
      // replaced wholesale — the same pattern as the dispose hook above),
      // and a late cancel of the replaced listener cannot deliver fresh
      // events after this line re-subscribes.
      unawaited(_sub?.cancel());
      _sub = _complaints
          .watchMissedCollectionComplaints(
        wardIds: route.wardIds,
        day: _collectionDay(session),
        statuses: const <ComplaintStatus>[
          ComplaintStatus.received,
          ComplaintStatus.assigned,
        ],
      )
          .listen(_onList, onError: _onListError);
    } on Exception {
      state = const PendingReportsState(phase: PendingReportsPhase.error);
    }
  }

  /// The collection day passed to the repository: the calendar date whose
  /// fields are the shift session's **Today** (IST), i.e. the IST day of
  /// `trips.date`. The repository seam (fake and Firestore impl alike)
  /// brackets the day range from the passed value's calendar fields —
  /// `DateTime(day.year, day.month, day.day)` — so the IST-resolved fields
  /// must arrive here, not the 00:00-IST instant (whose UTC fields are the
  /// previous calendar day). Fields come from [todayIST] (domain clock,
  /// ruling 9/18), never the phone timezone; on IST devices the bracket is
  /// exactly the collection day.
  DateTime _collectionDay(ShiftSession session) {
    final day = todayIST(session.date);
    return DateTime(day.year, day.month, day.day);
  }

  void _onList(List<Complaint> reports) => state = reports.isEmpty
      ? const PendingReportsState(phase: PendingReportsPhase.empty)
      : PendingReportsState(
          phase: PendingReportsPhase.ready,
          reports: List.unmodifiable(
            // Newest first: the driver reads freshest report on top.
            reports..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
          ),
        );

  void _onListError(Object error) => state = PendingReportsState(
        phase: _isUnavailable(error)
            ? PendingReportsPhase.offline
            : PendingReportsPhase.error,
      );

  /// "Will Revisit": the tapped complaint becomes `assigned` — exactly one
  /// document update, no other fields or complaints touched.
  Future<void> markWillRevisit(String complaintId) =>
      _updateStatus(complaintId, ComplaintStatus.assigned);

  /// "Done": the tapped complaint becomes `resolved` with `resolvedAt`
  /// set (client clock — the model seam carries DateTime only, the same
  /// precedent as `trips.startedAt`; ruling 18). `resolvedPhotoUrl`
  /// stays unset; still exactly one document update.
  Future<void> markDone(String complaintId) => _updateStatus(
        complaintId,
        ComplaintStatus.resolved,
        resolvedAt: DateTime.now(),
      );

  Future<void> _updateStatus(
    String complaintId,
    ComplaintStatus status, {
    DateTime? resolvedAt,
  }) async {
    if (state.phase != PendingReportsPhase.ready ||
        !state.reports.any((complaint) => complaint.id == complaintId)) {
      return;
    }
    state = state.copyWith(
      actionsInFlight: <String>{...state.actionsInFlight, complaintId},
    );
    try {
      await _complaints.updateStatus(
        complaintId,
        status,
        resolvedAt: resolvedAt,
      );
      // The live re-emission drops the resolved row and clears the busy
      // stamp; remove it here too, for repos that do not re-emit.
      state = state.copyWith(
        actionsInFlight: <String>{
          for (final id in state.actionsInFlight)
            if (id != complaintId) id,
        },
      );
    } on Exception {
      // Write failed: the boring error state surfaces; Retry re-subscribes
      // and the untouched complaint re-renders at its original status.
      // Fire-and-forget cancel (see _runLoad): awaiting it would wedge the
      // chain inside the widget-test FakeAsync zone.
      unawaited(_sub?.cancel());
      _sub = null;
      state = const PendingReportsState(phase: PendingReportsPhase.error);
    }
  }

  /// Whether [error] is a transport-availability failure. Firestore
  /// surfaces it as a `unavailable` code; the shape is duck-typed so this
  /// feature file keeps its hands off Firebase (0.11) and the fake can
  /// throw the same shape.
  bool _isUnavailable(Object error) {
    try {
      return (error as dynamic).code == 'unavailable';
    } on NoSuchMethodError {
      return false;
    }
  }
}
