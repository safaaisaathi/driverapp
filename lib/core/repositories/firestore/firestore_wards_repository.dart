import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/models.dart';
import '../wards_repository.dart';

/// Firestore-backed [WardsRepository]: `wards` loads for the route map and the
/// single-route watcher.
final class FirestoreWardsRepository implements WardsRepository {
  FirestoreWardsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, Object?>> get _wards =>
      _db.collection('wards');

  @override
  Future<List<Ward>> readWardsByIds(List<String> ids) async {
    if (ids.isEmpty) {
      return const <Ward>[];
    }
    final snapshot = await _wards
        .where(FieldPath.documentId, whereIn: ids)
        .get();
    return snapshot.docs
        .map((doc) => Ward.fromMap(<String, Object?>{...doc.data(), 'id': doc.id}))
        .toList();
  }

  @override
  Stream<List<Ward>> watchRouteWards(String routeId) => _wards
      .where('routeId', isEqualTo: routeId)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map(
            (doc) => Ward.fromMap(<String, Object?>{...doc.data(), 'id': doc.id}),
          )
          .toList());
}
