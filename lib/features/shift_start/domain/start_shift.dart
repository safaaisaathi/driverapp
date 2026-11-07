/// Start Shift's callable core (PRD-2 §0.13 behaviour rules 3 + §0.16,
/// CHG-0003).
///
/// The trip, the van's open-trip marker and the `wardDuty` rows are created
/// by the `startShift` callable, atomically, on the server. The old client
/// writes (`trips` create, `vans.currentTripId`, `vans.status`) are gone:
/// two phones on one van raced for them and could orphan a shift.
///
/// The callable returns a fresh custom token carrying `currentTripId`. The
/// app signs in with it before the first trail write, because the trail rule
/// scopes on that claim.
library;

import '../../../core/config/firebase_bootstrap.dart' show MessagingGateway;
import '../../../core/contract/shift_gateway.dart';
import '../../../core/domain/ist_clock.dart';
import '../../../core/models/models.dart';
import '../data/fcm_topics.dart' show fcmTopicVanOf;
import 'shift_session.dart';

class StartShift {
  StartShift({
    required ShiftGateway gateway,
    required DriverSessionGateway session,
    required MessagingGateway messaging,
  })  : _gateway = gateway, // ignore: prefer_initializing_formals
        _session = session, // ignore: prefer_initializing_formals
        _messaging = messaging; // ignore: prefer_initializing_formals

  final ShiftGateway _gateway;

  final DriverSessionGateway _session;

  final MessagingGateway _messaging;

  /// True when the van already holds an open shift (`currentTripId` set
  /// while `status == on_shift`). The launch-resume check uses it to decide
  /// whether to ask the server at all: `startShift` would otherwise CREATE a
  /// shift for a driver who is not working.
  bool isResumable(Van van) =>
      van.currentTripId != null && van.status == VanStatus.onShift;

  /// Starts (or resumes) the shift on the server and returns the session for
  /// [ShiftController.activate].
  ///
  /// Resume is the server's call: when the van's marker still points at this
  /// driver's open trip, `startShift` writes nothing and returns the same
  /// trip id. A different driver's shift is refused with
  /// `vanHeldByAnotherDriver`, a broken marker with `staleMarker`; both reach
  /// the flow as a [ContractException].
  Future<ShiftSession> execute(Driver driver, DateTime now) async {
    final date = utcStartOfIstDay(now);
    final result = await _gateway.startShift(
      driverId: driver.id,
      date: date,
    );
    await _session.signInWithCustomToken(result.token);
    await _subscribeVanTopic(result.vanId);
    return ShiftSession(
      vanId: result.vanId,
      tripId: result.tripId,
      routeId: driver.routeId,
      startedAt: now,
      date: date,
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
