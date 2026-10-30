/// Start Shift's write core (ticket 4 extraction, PRD-2 §0.13 behaviour
/// rules 3 + §0.16): the trip-creation and van-marking behaviour used by
/// the driver-identity start-shift flow.
///
/// `execute` takes the confirmed `Driver` and writes `trip.driverId` +
/// `trip.wardIds` on a fresh start; `vans.currentTripId` + `status:
/// on_shift` + routeId-from-van handling are unchanged. One [StartShift]
/// instance per start attempt; stateless.
library;

import '../../../core/config/firebase_bootstrap.dart' show MessagingGateway;
import '../../../core/domain/ist_clock.dart';
import '../../../core/models/models.dart';
import '../../../core/repositories/repositories.dart';
import '../data/fcm_topics.dart' show fcmTopicVanOf;
import 'shift_session.dart';

/// The start attempt cannot proceed: the van's open shift belongs to
/// another driver, or the van's open-trip marker is inconsistent (a stale
/// `currentTripId`). The identity flow catches it and surfaces its
/// retryable `startFailed` state - never a crash, never a takeover.
class ShiftStartConflict implements Exception {
  const ShiftStartConflict(this.message);

  final String message;

  @override
  String toString() => 'ShiftStartConflict: $message';
}

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

  /// Turns a van + the confirmed driver into a running shift and returns the
  /// session for [ShiftController.activate].
  ///
  /// Fresh: creates the 0.2 `trips` doc (vanId, routeId from the van,
  /// driverId + wardIds from the driver per 0.16, date = today IST,
  /// startedAt), sets `vans.status = on_shift` and `vans.currentTripId`,
  /// subscribes to topic `van_{vanId}`.
  /// Resume: reattaches the existing trip doc — a second `createTrip` is
  /// never issued, and the trip is reattached ONLY when the confirmed
  /// driver owns the open shift (vans can be shared between drivers, PRD-2
  /// §0.16 resume ruling: a different driver's start fails, it never takes
  /// over another driver's wards). Write failures surface to the caller's
  /// failure state.
  Future<ShiftSession> execute(Van van, Driver driver, DateTime now) async {
    final ShiftSession session;
    if (isResumable(van)) {
      // Grilled decision: RESUME, never duplicate.
      session = await _resumeSession(van, driver, now);
    } else {
      session = await _createTripAndMarkVan(van, driver, now);
    }
    await _subscribeVanTopic(van.id);
    return session;
  }

  /// Fresh start (0.13 behaviour rules 3 + 0.16 driver identity): trip doc +
  /// van marker writes, in that order, each through its repository.
  Future<ShiftSession> _createTripAndMarkVan(
    Van van,
    Driver driver,
    DateTime now,
  ) async {
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
      driverId: driver.id,
      wardIds: driver.wardIds,
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
  /// (read, not watch — the resume reattach is a one-time decision). The
  /// marker must agree with the van, and the open trip must belong to the
  /// confirmed driver; anything else is a [ShiftStartConflict] (stale
  /// marker, or another driver's shift on this shared van), never a
  /// takeover and never invented state.
  Future<ShiftSession> _resumeSession(
    Van van,
    Driver driver,
    DateTime now,
  ) async {
    final tripId = van.currentTripId!;
    final todayTrip = await _trips.readTrip(tripId);
    if (todayTrip != null && todayTrip.vanId != van.id) {
      // Defensive: the referenced trip belongs to another van — treat the
      // marker as stale and fail the reattach surface.
      throw ShiftStartConflict('trip "$tripId" does not match this van');
    }
    if (todayTrip != null &&
        todayTrip.driverId.isNotEmpty &&
        todayTrip.driverId != driver.id) {
      // Another driver owns the van's open shift (vans are shared between
      // driver accounts): block. Taking over would show the other driver's
      // wards and write marks into their trip doc. The trip is NEVER
      // rewritten here; the admin console clears the marker instead.
      throw ShiftStartConflict(
        'trip "$tripId" belongs to driver "${todayTrip.driverId}", '
        'not "${driver.id}"',
      );
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
