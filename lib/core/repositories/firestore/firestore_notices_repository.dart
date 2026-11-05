import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/models.dart';
import '../notices_repository.dart';
import '../notice_ward_chunks.dart';

/// Firestore-backed [NoticesRepository].
///
/// The inbox filter mirrors sendNotice fan-out (0.7): targetType `all`, or
/// `van` with targetId == vanId, or `ward` with targetId in the route's wards.
/// That is one OR (disjunctive) query. It needs the `(targetType, targetId)`
/// composite index declared in `firestore.indexes.json` (the `all` branch uses
/// the automatic single-field index). The route's ward list is CHUNKED (B-04)
/// because Firestore normalizes a `whereIn` inside an OR into one disjunction
/// per value and caps the query at 30; a 29-ward route used to fail with HTTP
/// 400. Chunks are merged by notice id, so `all`/`van` notices are not
/// duplicated. Ordering stays in-repository: newest `createdAt` first.
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
    final chunks = chunkNoticeWardIds(wardIds);
    if (chunks.length <= 1) {
      return _query(vanId, chunks.isEmpty ? const <String>[] : chunks.single)
          .snapshots()
          .map(_toNotices);
    }
    return _watchChunks(vanId, chunks);
  }

  Query<Map<String, Object?>> _query(String vanId, List<String> wardIds) {
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
    return wardBranch == null
        ? _notices.where(Filter.or(allBranch, vanBranch))
        : _notices.where(Filter.or(allBranch, vanBranch, wardBranch));
  }

  List<Notice> _toNotices(QuerySnapshot<Map<String, Object?>> snapshot) {
    return snapshot.docs
        .map(
          (doc) =>
              Notice.fromMap(<String, Object?>{...doc.data(), 'id': doc.id}),
        )
        .toList();
  }

  /// Joins the chunk queries into one newest-first inbox. Every chunk carries
  /// the `all` and `van` branches, so the merge de-duplicates by notice id.
  Stream<List<Notice>> _watchChunks(String vanId, List<List<String>> chunks) {
    return Stream<List<Notice>>.multi((controller) {
      final latest = List<List<Notice>>.filled(chunks.length, const <Notice>[]);
      final subscriptions =
          <StreamSubscription<QuerySnapshot<Map<String, Object?>>>>[];
      var cancelled = false;

      void emit() {
        if (cancelled) return;
        final byId = <String, Notice>{};
        for (final batch in latest) {
          for (final notice in batch) {
            byId[notice.id] = notice;
          }
        }
        final merged = byId.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        controller.add(merged);
      }

      for (var index = 0; index < chunks.length; index++) {
        final chunkIndex = index;
        subscriptions.add(
          _query(vanId, chunks[chunkIndex]).snapshots().listen(
            (snapshot) {
              latest[chunkIndex] = _toNotices(snapshot);
              emit();
            },
            onError: controller.addError,
          ),
        );
      }

      controller.onCancel = () async {
        cancelled = true;
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      };
    });
  }
}
