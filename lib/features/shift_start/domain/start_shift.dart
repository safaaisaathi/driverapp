/// Start Shift's write core (ticket 4 extraction, PRD-2 §0.13 behaviour
/// rules 3 + §0.16): the trip-creation and van-marking behaviour shared by
/// the old D1 flow controller and the new driver-identity flow.
///
/// Extracted verbatim from `ShiftStartFlowController` (expand, do not
/// break: the old controller delegates here and the F-D1 tests keep
/// passing). One [StartShift] instance per start attempt; stateless.
library;

import '../../../core/config/firebase_bootstrap.dart' show MessagingGateway;
import '../../../core/domain/ist_clock.dart';
import '../../../core/models/models.dart';
import '../../../core/repositories/repositories.dart';
import '../data/verify_driver_pin.dart' show fcmTopicVanOf;
import 'shift_session.dart';

class StartShift {
  StartShift({
    required TripsRepository trips,
    required VansRepository vans,
    required MessagingGateway messaging,
  })  : _trips = trips, // ignore: prefer_initializing_formals
        _vans = vans, // ignore: prefer_initializing_formals
        _messaging = messaging; // ignore: prefer_initializing_formals

  final TripsRepository _trips;

  final VansRepository _vans;

  final MessagingGateway _messaging;

  /// True when the van already holds an open shift (`currentTripId` set
  /// while `status == on_shift`): Start reattaches instead of duplicating.
  bool isResumable(Van van) =>
      van.currentTripId != null && van.status == VanStatus.onShift;

  /// Turns a van doc into a running shift and returns the session for
  /// [ShiftController.activate].
  ///
  /// Fresh: creates the 0.2 `trips` doc (vanId, routeId from the van,
  /// date = today IST, startedAt), sets `vans.status = on_shift` and
  /// `vans.currentTripId`, subscribes to topic `van_{vanId}`.
  /// Resume: reattaches the existing trip doc — a second `createTrip` is
  /// never issued. Write failures surface to the caller's failure state.
  Future<ShiftSession> execute(Van van, DateTime now) async {
    final ShiftSession session;
    if (isResumable(van)) {
      // Grilled decision: RESUME, never duplicate.
      session = await _resumeSession(van, now);
    } else {
      session = await _createTripAndMarkVan(van, now);
    }
    await _subscribeVanTopic(van.id);
    return session;
  }

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

  /// Resume branch: the existing trip's identity comes back untouched
  /// (read, not watch — the resume reattach is a one-time decision).
  Future<ShiftSession> _resumeSession(Van van, DateTime now) async {
    final tripId = van.currentTripId!;
    final todayTrip = await _trips.readTrip(tripId);
    if (todayTrip != null && todayTrip.vanId != van.id) {
      // Defensive: the referenced trip belongs to another van — treat the
      // marker as stale and fail the reattach surface, never invent state.
      throw StateError('currentTripId "$tripId" does not match this van');
    }
    return ShiftSession(
      vanId: van.id,
      tripId: tripId,
      routeId: van.routeId,
      startedAt: todayTrip?.startedAt ?? now,
      date: todayTrip?.date ?? utcStartOfIstDay(now),
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
}
