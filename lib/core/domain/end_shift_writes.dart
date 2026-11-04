/// The End Shift action (PRD-2 F-D5, CHG-0003), shared by the manual D5 flow
/// and the depot auto-end (ruling #29).
///
/// The trip close and the van's marker are the server's write: `endShift`
/// runs one transaction that sets `trips.endedAt` + `status = ended` and
/// clears `vans.currentTripId` ONLY when the marker still points at this
/// trip. The app's write set is therefore just the call plus the tracking
/// stop, so the two entry points can never drift.
library;

import '../contract/shift_gateway.dart';

/// Calls `endShift` and then stops tracking.
///
/// A tracking stop failure never leaves the trip open, so [stopTracking] is
/// best effort (the callable already landed). Rethrows any callable failure
/// as a [ContractException] so the caller can show its failed state.
Future<void> writeEndShift({
  required ShiftGateway gateway,
  required String tripId,
  required Future<void> Function() stopTracking,
}) async {
  await gateway.endShift(tripId);
  try {
    await stopTracking();
  } catch (_) {
    // Service stop failure must not leave the trip open.
  }
}
