import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/models.dart';
import '../drivers_repository.dart';

/// Firestore-backed [DriversRepository] (0.16): a signed-in read of
/// `drivers/{CODE}` where the doc id is the normalized driver code.
final class FirestoreDriversRepository implements DriversRepository {
  FirestoreDriversRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, Object?>> get _drivers =>
      _db.collection('drivers');

  @override
  Future<Driver?> fetchDriver(String rawCode) async {
    // Normalization first: a bad shape returns null and never reaches
    // Firestore (0.16).
    final code = normalizeDriverCode(rawCode);
    if (code == null) return null;
    final snapshot = await _drivers.doc(code).get();
    if (!snapshot.exists) return null;
    return Driver.fromMap(_docDataWithId(snapshot.id, snapshot.data()!));
  }

  Map<String, Object?> _docDataWithId(String id, Map<String, Object?> data) =>
      <String, Object?>{...data, 'id': id};
}
