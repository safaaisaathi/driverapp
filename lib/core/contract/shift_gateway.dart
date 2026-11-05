/// The callable seam (02-contracts/callables.json). One interface per
/// authority family the driver app calls, so the flows never touch Firebase
/// types and tests script the server without a network.
///
/// The app calls exactly these six:
/// - `bindDeviceToVan` and `signInWithCustomToken` ([DriverSessionGateway]),
/// - `startShift`, `endShift` and `markWardDone` ([ShiftGateway]),
/// - `flagMockLocation` ([TrackingGateway], in `tracking_gateway.dart`).
///
/// A callable is the mechanism when a LIVE DOCUMENT is the authority
/// (`callables.json#/x-decision-rule`). The trips and the shift markers are
/// therefore server-owned: the app never writes `trips` (the trail chunk is
/// the one documented exception) and never writes `vans.currentTripId`.
library;

import 'reason_codes.dart';

/// The result of `bindDeviceToVan` (callables.json).
final class DriverBinding {
  const DriverBinding({
    required this.token,
    required this.vanId,
    required this.driverId,
    required this.claimMode,
  });

  /// The custom token to sign in with. Its claims are `vanId` + `driverId`.
  final String token;

  final String vanId;

  final String driverId;

  /// `vanDevice.claimMode`: `firstClaim` or `preProvisioned`.
  final String claimMode;
}

/// The result of `startShift` (callables.json).
final class ShiftStartResult {
  const ShiftStartResult({
    required this.token,
    required this.tripId,
    required this.vanId,
  });

  /// A fresh custom token carrying `currentTripId` as well as `vanId` and
  /// `driverId`. The app signs in with it before the first trail write.
  final String token;

  final String tripId;

  final String vanId;
}

/// The driver's session: the bind callable plus the Auth sign-in that puts
/// its claims on the token. A bind failure is surfaced as a
/// [ContractException]; there is no silent anonymous fallback.
abstract interface class DriverSessionGateway {
  /// `bindDeviceToVan({driverCode, installId})`. [installId] is a stable
  /// per-install id, never a per-launch value (the callable's note).
  Future<DriverBinding> bindDeviceToVan({
    required String driverCode,
    required String installId,
  });

  /// Signs in with the custom token from a bind or a shift start.
  Future<void> signInWithCustomToken(String token);
}

/// The three shift calls. Every one is a live-document decision, so the
/// server owns the write; the app reads the result back through its streams.
abstract interface class ShiftGateway {
  /// `startShift({driverId, date})`. [date] is the IST midnight instant of
  /// the shift's day (callables.json), not a date string.
  Future<ShiftStartResult> startShift({
    required String driverId,
    required DateTime date,
  });

  /// `endShift({tripId})`. Returns the server's `endedAt`.
  Future<DateTime> endShift(String tripId);

  /// `markWardDone({tripId, wardId, flagged})`. The server appends the
  /// entry and flips the citizen's `wardDuty` row. The trip stream the screen
  /// already watches re-emits the new `wardsDone`.
  Future<void> markWardDone({
    required String tripId,
    required String wardId,
    required bool flagged,
  });
}
