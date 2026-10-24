import '../models/models.dart';

/// Data access for the `complaints` collection, driver scope (0.8, 0.13).
///
/// The driver only sees Pending Reports (Glossary): `missed_collection`
/// complaints for today's route wards that await driver action, and only ever
/// updates their `status` (`assigned` for "Will Revisit", `resolved` for
/// "Done") — all other fields belong to the user app or staff.
abstract class ComplaintsRepository {
  /// Stream of Pending Reports across [wardIds] created on [day] currently in
  /// one of [statuses] (the driver cares about `received` and `assigned`).
  ///
  /// Implemented via whereIn on `wardId` plus a `createdAt` day range, with
  /// [statuses] filtered on the repository side — Firestore allows only one
  /// `whereIn` clause per query, and that discrepancy is reported to the
  /// contract owner, not worked around with a schema change.
  Stream<List<Complaint>> watchMissedCollectionComplaints({
    required List<String> wardIds,
    required DateTime day,
    required List<ComplaintStatus> statuses,
  });

  /// Updates a complaint's status; when [resolvedAt] is given it is written
  /// alongside (the resolved case, 0.2 shape).
  Future<void> updateStatus(
    String complaintId,
    ComplaintStatus status, {
    DateTime? resolvedAt,
  });
}
