/// The reason-code vocabulary the platform sends (02-contracts/errors.json).
///
/// The server sends a code. The client owns the words. Nothing here carries
/// English text, and a screen never shows a raw code.
library;

/// Every code in `errors.json`, plus two client-side outcomes: [offline]
/// (the phone has no network, so the server never saw the call) and
/// [unknown] (a code this build does not know, or a transport failure).
enum ReasonCode {
  invalidInput('invalidInput'),
  notAuthorised('notAuthorised'),
  notFound('notFound'),
  rateLimited('rateLimited'),
  invalidState('invalidState'),
  vanAlreadyClaimed('vanAlreadyClaimed'),
  vanHeldByAnotherDriver('vanHeldByAnotherDriver'),
  staleMarker('staleMarker'),
  internal('internal'),

  /// Client only: no network. The call was not made (errors.json
  /// `CLIENT_ONLY_REASON_CODES`).
  offline('offline'),

  /// Client only: a transport failure, or a code this build does not know.
  unknown('unknown');

  const ReasonCode(this.value);

  /// The exact contract string.
  final String value;

  /// Parses a server message into a code. The platform's callables throw an
  /// `HttpsError` whose MESSAGE is the reason code (see the platform's
  /// `reasonCodes.ts`), so this is a message lookup, never a text match.
  static ReasonCode parse(Object? raw) {
    if (raw is String) {
      for (final code in values) {
        if (code.value == raw) return code;
      }
    }
    return ReasonCode.unknown;
  }
}

/// A callable refused the request with a contract reason code.
class ContractException implements Exception {
  const ContractException(this.code, {this.cause});

  final ReasonCode code;

  /// The original error, never shown to the driver.
  final Object? cause;

  @override
  String toString() => 'ContractException(${code.value})';
}
