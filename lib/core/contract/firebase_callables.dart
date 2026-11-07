/// Firebase-backed implementations of the callable seam.
///
/// Error translation lives here and only here: the platform throws an
/// `HttpsError` whose MESSAGE is a reason code (`errors.json`), so the app
/// turns it into a [ContractException] and every screen switches on the code.
library;

import 'package:cloud_functions/cloud_functions.dart';
// `firebase_auth` re-exports `FirebaseException`, so no separate firebase_core
// import is needed here.
import 'package:firebase_auth/firebase_auth.dart';

import 'reason_codes.dart';
import 'shift_gateway.dart';
import 'tracking_gateway.dart';

/// Maps a callable failure to a contract code. `unavailable` and a dead
/// network are the client-only `offline`; anything else the server did not
/// name is `unknown` (never a raw message on screen).
ReasonCode reasonCodeOfCallableError(Object error) {
  if (error is FirebaseFunctionsException) {
    // `unavailable` is the Functions transport failing to reach the
    // emulator/cloud, not a decision the server made.
    if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
      return ReasonCode.offline;
    }
    // The server puts the reason code in the message. An empty or
    // plain-words message is a transport/internal surprise, not a code.
    return ReasonCode.parse(error.message);
  }
  if (error is FirebaseException &&
      (error.code == 'unavailable' || error.code == 'network-request-failed')) {
    return ReasonCode.offline;
  }
  return ReasonCode.unknown;
}

/// The real device-to-van bind and the custom-token sign-in.
final class FirebaseDriverSessionGateway implements DriverSessionGateway {
  FirebaseDriverSessionGateway(this._functions, this._auth);

  final FirebaseFunctions _functions;

  final FirebaseAuth _auth;

  @override
  Future<DriverBinding> bindDeviceToVan({
    required String driverCode,
    required String installId,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('bindDeviceToVan')
          .call<Map<String, dynamic>>(<String, Object?>{
        'driverCode': driverCode,
        'installId': installId,
      });
      final data = result.data;
      return DriverBinding(
        token: data['token'] as String,
        vanId: data['vanId'] as String,
        driverId: data['driverId'] as String,
        claimMode: data['claimMode'] as String? ?? 'firstClaim',
      );
    } on Exception catch (error) {
      throw ContractException(reasonCodeOfCallableError(error), cause: error);
    }
  }

  @override
  Future<void> signInWithCustomToken(String token) async {
    try {
      await _auth.signInWithCustomToken(token);
    } on Exception catch (error) {
      throw ContractException(reasonCodeOfCallableError(error), cause: error);
    }
  }
}

/// The three shift calls.
final class FirebaseShiftGateway implements ShiftGateway {
  FirebaseShiftGateway(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<ShiftStartResult> startShift({
    required String driverId,
    required DateTime date,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('startShift')
          .call<Map<String, dynamic>>(<String, Object?>{
        'driverId': driverId,
        'date': date.toUtc().toIso8601String(),
      });
      final data = result.data;
      return ShiftStartResult(
        token: data['token'] as String,
        tripId: data['tripId'] as String,
        vanId: data['vanId'] as String,
      );
    } on Exception catch (error) {
      throw ContractException(reasonCodeOfCallableError(error), cause: error);
    }
  }

  @override
  Future<DateTime> endShift(String tripId) async {
    try {
      final result = await _functions
          .httpsCallable('endShift')
          .call<Map<String, dynamic>>(<String, Object?>{'tripId': tripId});
      final raw = result.data['endedAt'];
      return raw is String ? DateTime.parse(raw) : DateTime.now();
    } on Exception catch (error) {
      throw ContractException(reasonCodeOfCallableError(error), cause: error);
    }
  }

  @override
  Future<void> markWardDone({
    required String tripId,
    required String wardId,
    required bool flagged,
  }) async {
    try {
      await _functions
          .httpsCallable('markWardDone')
          .call<Map<String, dynamic>>(<String, Object?>{
        'tripId': tripId,
        'wardId': wardId,
        'flagged': flagged,
      });
    } on Exception catch (error) {
      throw ContractException(reasonCodeOfCallableError(error), cause: error);
    }
  }
}

/// `flagMockLocation` (CHG-0017): the durable mock-location latch.
final class FirebaseTrackingGateway implements TrackingGateway {
  FirebaseTrackingGateway(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<MockLocationFlag> flagMockLocation(String tripId) async {
    try {
      final result = await _functions
          .httpsCallable('flagMockLocation')
          .call<Map<String, dynamic>>(<String, Object?>{'tripId': tripId});
      final data = result.data;
      final flaggedAt = data['flaggedAt'];
      return MockLocationFlag(
        flagged: data['flagged'] is bool ? data['flagged'] as bool : false,
        flaggedAt: flaggedAt is String ? DateTime.tryParse(flaggedAt) : null,
      );
    } on Exception catch (error) {
      throw ContractException(reasonCodeOfCallableError(error), cause: error);
    }
  }
}
