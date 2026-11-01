/// The exact End Shift write set (PRD-2 F-D5), shared by the manual D5 flow
/// and the depot auto-end (ruling #29).
///
/// One home for the mutation order so the two entry points can never drift:
/// 1. `trips.endedAt` = [endedAt] (default now),
/// 2. `vans.status = idle`,
/// 3. `vans.currentTripId = null`,
/// 4. stop tracking (trail flush + foreground service).
library;

import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repositories.dart';

/// Performs the End Shift writes and then stops tracking.
///
/// A tracking stop failure never leaves the trip open, so [stopTracking] is
/// best effort (the repository writes above already landed). Rethrows any
/// Firestore failure so the caller can show its failed state.
Future<void> writeEndShift({
  required VansRepository vans,
  required TripsRepository trips,
  required String vanId,
  required String tripId,
  required Future<void> Function() stopTracking,
  DateTime? endedAt,
}) async {
  await trips.setEndedAt(tripId, endedAt ?? DateTime.now());
  await vans.updateStatus(vanId, VanStatus.idle);
  await vans.updateCurrentTripId(vanId, null);
  try {
    await stopTracking();
  } catch (_) {
    // Service stop failure must not leave the trip open.
  }
}
