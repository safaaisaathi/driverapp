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
}
