import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/models.dart';
import '../complaints_repository.dart';

/// Firestore-backed [ComplaintsRepository] for the driver's Pending Reports
/// scope (0.8: a driver may only read/update `missed_collection` complaints of
/// its route's wards).
///
/// Query shape: equality on `category`, `whereIn` on `wardId`, the createdAt
/// day range, then the most recent 200 by `createdAt` descending.
/// [ComplaintStatus] filtering stays in this class because Firestore does not
/// allow two `whereIn` clauses in one query.
///
/// The cap is audit B-05 option A. It bounds a read that used to download every
/// complaint in the day window only to throw the resolved ones away. The
/// descending sort needs the platform index
/// `(category ASC, wardId ASC, createdAt DESC)`. That index is requested in
/// platform issue #5 and must be deployed before this query ships.
final class FirestoreComplaintsRepository implements ComplaintsRepository {
  FirestoreComplaintsRepository(this._db);

  /// The most complaints one screen fetches. Audit B-05 option A.
  static const int _fetchLimit = 200;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, Object?>> get _complaints =>
      _db.collection('complaints');

  @override
  Stream<List<Complaint>> watchMissedCollectionComplaints({
    required List<String> wardIds,
    required DateTime day,
    required List<ComplaintStatus> statuses,
  }) {
    if (wardIds.isEmpty) {
      return Stream.value(const <Complaint>[]);
    }
    final dayStart = Timestamp.fromDate(DateTime(day.year, day.month, day.day));
    final dayEnd = Timestamp.fromDate(
      DateTime(day.year, day.month, day.day).add(const Duration(days: 1)),
    );
    return _complaints
        .where('category', isEqualTo: 'missed_collection')
        .where('wardId', whereIn: wardIds)
        .where('createdAt', isGreaterThanOrEqualTo: dayStart)
        .where('createdAt', isLessThan: dayEnd)
        .orderBy('createdAt', descending: true)
        .limit(_fetchLimit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(
              (doc) => Complaint.fromMap(
                <String, Object?>{...doc.data(), 'id': doc.id},
              ),
            )
            .where((complaint) => statuses.contains(complaint.status))
            .toList());
  }

  @override
  Future<void> updateStatus(
    String complaintId,
    ComplaintStatus status, {
    DateTime? resolvedAt,
  }) {
    final data = <String, Object?>{'status': status.value};
    if (resolvedAt != null) {
      data['resolvedAt'] = dateTimeToDocTime(resolvedAt)!;
    }
    return _complaints.doc(complaintId).update(data);
  }
}
