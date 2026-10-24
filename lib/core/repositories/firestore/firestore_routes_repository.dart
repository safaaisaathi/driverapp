import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/models.dart';
import '../routes_repository.dart';

/// Firestore-backed [RoutesRepository].
final class FirestoreRoutesRepository implements RoutesRepository {
  FirestoreRoutesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, Object?>> get _routes =>
      _db.collection('routes');

  @override
  Future<RouteModel?> readRoute(String routeId) async {
    final snapshot = await _routes.doc(routeId).get();
    if (!snapshot.exists) {
      return null;
    }
    final data = <String, Object?>{...snapshot.data()!, 'id': snapshot.id};
    return RouteModel.fromMap(data);
  }
}
