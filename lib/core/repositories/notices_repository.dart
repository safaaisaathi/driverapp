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
}
