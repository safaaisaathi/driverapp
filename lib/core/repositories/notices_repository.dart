import '../models/models.dart';

/// Data access for the `notices` collection (0.2).
///
/// A Notice is a one-way message (Glossary). The driver inbox shows notices
/// addressed to the van, to the route's wards, or to everyone; the filter
/// expressed by this stream's parameters mirrors Flow "sendNotice" fan-out
/// (0.7) client-side. Filtering happens inside the repository — widgets stay
/// Firebase-free (0.11).
abstract class NoticesRepository {
  /// Stream of notices the given van should see: targetType `all`, or
  /// targetType `van` with `targetId == vanId`, or targetType `ward` with
  /// `targetId` in [wardIds] — newest first (descending `createdAt`).
  ///
  /// [wardIds] is the route's ward list (per stall semantics: driver reads
  /// `wards` by `routeId`). Pass the current list each subscription.
  Stream<List<Notice>> watchNotices({
    required String vanId,
    required List<String> wardIds,
  });

  /// The ids in [noticeIds] whose `notices/{noticeId}/receipts/{driverCode}`
  /// doc exists (CHG-0018). Reads the Firestore cache first, so an offline
  /// driver still sees the right dots; a failed read returns nothing and the
  /// session-local set stays the fallback.
  ///
  /// [driverCode] must be the `driverId` claim: the strict rules compare the
  /// receipt doc id with the claim, so any other value is denied.
  Future<Set<String>> readReceipts({
    required String driverCode,
    required Iterable<String> noticeIds,
  });

  /// Writes `notices/{noticeId}/receipts/{driverCode}` with `readAt` set by
  /// the server clock. `readAt` is the only field the rules allow.
  Future<void> writeReceipt({
    required String driverCode,
    required String noticeId,
  });
}
