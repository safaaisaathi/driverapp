import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/models.dart';
import '../notices_repository.dart';

/// Firestore-backed [NoticesRepository].
///
/// The inbox filter mirrors sendNotice fan-out (0.7): targetType `all`, or
/// `van` with targetId == vanId, or `ward` with targetId in the route's wards.
/// This is one OR (disjunctive) query; the ordering is applied in-repository
/// (descending createdAt) instead of in the query, so no composite index is
/// required beyond Firestore's automatic single-field indexes.
final class FirestoreNoticesRepository implements NoticesRepository {
  FirestoreNoticesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, Object?>> get _notices =>
      _db.collection('notices');

  @override
  Stream<List<Notice>> watchNotices({
    required String vanId,
    required List<String> wardIds,
  }) {
    final allBranch = Filter('targetType', isEqualTo: 'all');
    final vanBranch = Filter.and(
      Filter('targetType', isEqualTo: 'van'),
      Filter('targetId', isEqualTo: vanId),
    );
    final wardBranch = wardIds.isEmpty
        ? null
        : Filter.and(
            Filter('targetType', isEqualTo: 'ward'),
            Filter('targetId', whereIn: wardIds),
          );
    final query = wardBranch == null
        ? _notices.where(Filter.or(allBranch, vanBranch))
        : _notices.where(Filter.or(allBranch, vanBranch, wardBranch));
    return query.snapshots().map((snapshot) {
      final notices = snapshot.docs
          .map(
            (doc) => Notice.fromMap(<String, Object?>{...doc.data(), 'id': doc.id}),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notices;
    });
  }

  /// One `get` per notice on its receipt doc. A collection-group query would
  /// be cheaper, but the rules authorize a receipt by its doc id
  /// (`isOwnDriver(driverCode)`), and a group query cannot be authorized per
  /// doc that way.
  @override
  Future<Set<String>> readReceipts({
    required String driverCode,
    required Iterable<String> noticeIds,
  }) async {
    final read = <String>{};
    final ids = noticeIds.toList();
    if (driverCode.isEmpty || ids.isEmpty) return read;
    await Future.wait(
      ids.map((noticeId) async {
        final snapshot = await _notices
            .doc(noticeId)
            .collection('receipts')
            .doc(driverCode)
            .get();
        if (snapshot.exists) read.add(noticeId);
      }),
    );
    return read;
  }

  @override
  Future<void> writeReceipt({
    required String driverCode,
    required String noticeId,
  }) {
    // `readAt` is the only key the strict rules allow (CHG-0018). The server
    // clock, not the device clock, stamps it.
    return _notices
        .doc(noticeId)
        .collection('receipts')
        .doc(driverCode)
        .set(<String, Object?>{
          'readAt': FieldValue.serverTimestamp(),
        });
  }
}
