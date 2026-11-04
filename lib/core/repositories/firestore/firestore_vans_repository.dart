import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/models.dart';
import '../vans_repository.dart';

/// Firestore-backed [VansRepository]. All driver-scoped van writes land here
/// (`vans.lastLocation`, `vans.status`, `vans.batteryPct` — 0.8 write scope).
final class FirestoreVansRepository implements VansRepository {
  FirestoreVansRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, Object?>> get _vans =>
      _db.collection('vans');

  @override
  Future<List<Van>> readVans() async {
    final snapshot = await _vans.get();
    return snapshot.docs.map(_vanFromDoc).toList();
  }

  @override
  Future<Van?> readVan(String vanId) async {
    final snapshot = await _vans.doc(vanId).get();
    if (!snapshot.exists) return null;
    final data = snapshot.data()!;
    return Van.fromMap(_docDataWithId(snapshot.id, data));
  }

  @override
  Stream<Van?> watchVan(String vanId) => _vans.doc(vanId).snapshots().map((snap) {
        if (!snap.exists) return null;
        return Van.fromMap(_docDataWithId(snap.id, snap.data()!));
      });

  @override
  Future<void> updateLastLocation({
    required String vanId,
    required double lat,
    required double lng,
    required double speedKmph,
    DateTime? updatedAt,
  }) {
    // 0.13: lastLocation is one small overwritten object carrying a server
    // timestamp when the engine did not stamp one itself.
    final lastLocation = <String, Object?>{
      'lat': lat,
      'lng': lng,
      'updatedAt': updatedAt == null
          ? FieldValue.serverTimestamp()
          : dateTimeToDocTime(updatedAt)!,
      'speedKmph': speedKmph,
    };
    return _vans
        .doc(vanId)
        .update(<String, Object?>{'lastLocation': lastLocation});
  }

  @override
  Future<void> updateStatus(String vanId, VanStatus status) =>
      _vans.doc(vanId).update(<String, Object?>{'status': status.value});

  @override
  Future<void> updateBatteryPct(String vanId, int batteryPct) =>
      _vans.doc(vanId).update(<String, Object?>{'batteryPct': batteryPct});

  Van _vanFromDoc(QueryDocumentSnapshot<Map<String, Object?>> doc) =>
      Van.fromMap(_docDataWithId(doc.id, doc.data()));

  Map<String, Object?> _docDataWithId(String id, Map<String, Object?> data) =>
      <String, Object?>{...data, 'id': id};
}
