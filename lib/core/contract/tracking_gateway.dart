/// The tracking callable seam (02-contracts/callables.json).
///
/// `flagMockLocation` is the one write the tracking feature needs: the trip
/// is server-owned (`03-rules/firestore.strict.rules` denies every client trip
/// write), but only the phone knows a fix is mocked. The callable carries the
/// client's decision across the trust boundary and the server enforces the
/// one-way latch (CHG-0017).
library;

/// The result of `flagMockLocation` (callables.json).
final class MockLocationFlag {
  const MockLocationFlag({required this.flagged, this.flaggedAt});

  /// True when THIS call set the latch, false when it was already set. On a
  /// successful call the latch is true either way.
  final bool flagged;

  /// The server's time for THIS call, when it sent one. The latch itself
  /// stores no timestamp.
  final DateTime? flaggedAt;
}

abstract interface class TrackingGateway {
  /// `flagMockLocation({tripId})`. The server checks that the trip is the
  /// caller's and open, then writes `mockLocationDetected = true`. The call
  /// is idempotent: a retry after a dropped response writes nothing new.
  Future<MockLocationFlag> flagMockLocation(String tripId);
}
