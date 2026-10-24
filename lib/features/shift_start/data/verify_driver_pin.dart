/// PIN verification data layer (F-D1, PRD-2 0.7 `verifyDriverPin`).
///
/// The callable contract (0.7): input `{vanId, pin}`, rate-limited to 5
/// tries per 10 minutes, result `{token}` where `token` is a Firebase
/// custom auth token carrying the `vanId` claim. The backend function is
/// not deployed yet (Backend Owner dependency) — everything here is
/// programmatic against that contract, with a seam so tests never touch
/// platform channels.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/firebase_bootstrap.dart';
import '../../../core/config/firebase_options.dart';

/// FCM topic for one van (PRD-2 0.6.6: the driver app subscribes to
/// `van_{vanId}` after shift start). Naming lives with the shift feature;
/// `fcmTopicAll` stays in bootstrap.
String fcmTopicVanOf(String vanId) => 'van_$vanId';

/// Failure kinds surfaced by [DriverPinVerifier] — each maps to one
/// friendly, localized message on D1 (0.11: no backend jargon in UI).
enum DriverPinFailureKind {
  /// Wrong PIN (or the PIN does not match any van): friendly retry message.
  wrongPin,

  /// The 5-tries-per-10-minutes rate limit from the function fired:
  /// "locked out" message, no crash, retries allowed later (0.7).
  lockedOut,

  /// Backend/network unavailable (partial boot, emulator down): generic
  /// error state with retry.
  unavailable,
}

/// Thrown by [DriverPinVerifier] on a failed verification; [kind] drives
/// the localized UI message. Never leaks Firebase type names upward.
final class DriverPinException implements Exception {
  const DriverPinException(this.kind, {this.cause});

  final DriverPinFailureKind kind;

  /// Details for logging/tests only; never shown raw in the UI.
  final Object? cause;

  @override
  String toString() => 'DriverPinException(${kind.name}, cause: $cause)';
}

/// Seam: verify a driver PIN against `vanSecrets` via the callable and
/// return the custom auth token. Tests inject fakes (spec seam 1).
abstract interface class DriverPinVerifier {
  Future<String> verifyPin({required String vanId, required String pin});
}

/// Real verifier: calls the `verifyDriverPin` Cloud Function through the
/// Firebase Functions emulator wiring (`useFunctionsEmulator` is applied
/// here, at the only place a callable is constructed — same host/port
/// constants as the rest of the Emulator Suite setup).
final class FirebaseCallablePinVerifier implements DriverPinVerifier {
  FirebaseCallablePinVerifier(FirebaseApp app)
      : _functions =
            FirebaseFunctions.instanceFor(app: app)..useFunctionsEmulator(
              kFirebaseEmulatorHost,
              kFunctionsEmulatorPort,
            );

  final FirebaseFunctions _functions;

  /// Exact callable name from 0.7 — do not rename without the Backend
  /// Owner (0.15.4).
  static const String callableName = 'verifyDriverPin';

  @override
  Future<String> verifyPin({
    required String vanId,
    required String pin,
  }) async {
    final callable = _functions.httpsCallable(
      callableName,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );
    try {
      // 0.7 contract: input {vanId, pin}, result {token}.
      final result = await callable.call(<String, Object?>{
        'vanId': vanId,
        'pin': pin,
      });
      final token = result.data is Map<Object?, Object?>
          ? (result.data as Map<Object?, Object?>)['token']
          : null;
      if (token is! String || token.isEmpty) {
        throw DriverPinException(
          DriverPinFailureKind.unavailable,
          cause: 'verifyDriverPin returned no token payload',
        );
      }
      return token;
    } on FirebaseFunctionsException catch (error) {
      throw DriverPinException(_mapCode(error.code), cause: error);
    } on Exception catch (error) {
      throw DriverPinException(DriverPinFailureKind.unavailable, cause: error);
    }
  }

  /// Code mapping follows the typical callable error policy (backend not
  /// deployed yet — refined when the real payload surface lands):
  /// auth-ish codes ⇒ wrong PIN, `resource-exhausted` ⇒ the 0.7 rate
  /// limit, everything else ⇒ backend/network unavailable.
  DriverPinFailureKind _mapCode(String code) => switch (code) {
        'unauthenticated' ||
        'permission-denied' ||
        'invalid-argument' ||
        'not-found' =>
          DriverPinFailureKind.wrongPin,
        'resource-exhausted' => DriverPinFailureKind.lockedOut,
        _ => DriverPinFailureKind.unavailable,
      };
}

/// Seam: sign in with the custom token returned by [DriverPinVerifier]
/// (PRD-2 0.13 step 2: `signInWithCustomToken`). Returns the driver uid.
abstract interface class DriverAuthGateway {
  Future<String> signInWithCustomToken(String token);
}

/// Real gateway against the default Firebase app the bootstrap prepared.
final class FirebaseAuthGateway implements DriverAuthGateway {
  const FirebaseAuthGateway();

  @override
  Future<String> signInWithCustomToken(String token) async {
    final credential = await FirebaseAuth.instanceFor(
      app: Firebase.app(),
    ).signInWithCustomToken(token);
    final user = credential.user;
    if (user == null) {
      throw StateError('signInWithCustomToken returned no user (F-D1)');
    }
    return user.uid;
  }
}

// ---------------------------------------------------------------------------
// Providers (overridden with fakes in tests)
// ---------------------------------------------------------------------------

/// [DriverPinVerifier] provider.
final Provider<DriverPinVerifier> pinVerifierProvider = Provider<DriverPinVerifier>(
  (ref) => FirebaseCallablePinVerifier(Firebase.app()),
);

/// [DriverAuthGateway] provider.
final Provider<DriverAuthGateway> driverAuthGatewayProvider =
    Provider<DriverAuthGateway>((ref) => const FirebaseAuthGateway());

/// Messaging seam reuse (topic `van_{vanId}` subscription after start).
final Provider<MessagingGateway> driverMessagingGatewayProvider =
    Provider<MessagingGateway>((ref) => const FirebaseMessagingGateway());
