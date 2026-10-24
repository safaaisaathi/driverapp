import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/models.dart';
import '../complaints_repository.dart';

/// Firestore-backed [ComplaintsRepository] for the driver's Pending Reports
/// scope (0.8: a driver may only read/update `missed_collection` complaints of
/// its route's wards).
///
/// Query shape: equality on `category`, `whereIn` on `wardId`, createdAt day
/// range in Firestore, [ComplaintStatus] filtering applied in this class —
/// Firestore does not allow two `whereIn` clauses in one query. Reported to
/// the contract owner as gap #C-03 in the ticket report.
final class FirestoreComplaintsRepository implements ComplaintsRepository {
  FirestoreComplaintsRepository(this._db);

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
