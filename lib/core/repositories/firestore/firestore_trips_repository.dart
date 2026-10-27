import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/models.dart';
import '../trips_repository.dart';

/// Firestore-backed [TripsRepository]: trip create (Flow A step 1), Mark Ward
/// Done and Trail appends (steps 2–4), End Shift close, and today's-trip
/// watching for the resume-never-duplicate seam.
final class FirestoreTripsRepository implements TripsRepository {
  FirestoreTripsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, Object?>> get _trips =>
      _db.collection('trips');

  @override
  Future<Trip> createTrip(Trip trip) async {
    final reference = _trips.doc();
    // The `id` key mirrors 0.2 exactly (round-trip shapes carry it).
    final data = <String, Object?>{...trip.toMap(), 'id': reference.id};
    await reference.set(data);
    return Trip.fromMap(data);
  }

  @override
  Future<void> appendWardDone(String tripId, WardDone entry) =>
      _trips.doc(tripId).update(<String, Object?>{
        'wardsDone': FieldValue.arrayUnion(<Object?>[entry.toMap()]),
      });

  @override
  Future<void> appendGpsTrail(String tripId, List<GpsPoint> points) =>
      _trips.doc(tripId).update(<String, Object?>{
        'gpsTrail':
            FieldValue.arrayUnion(points.map((point) => point.toMap()).toList()),
      });

  @override
  Future<void> setEndedAt(String tripId, DateTime endedAt) =>
      _trips.doc(tripId).update(<String, Object?>{
        'endedAt': dateTimeToDocTime(endedAt)!,
      });

  @override
  Future<void> setMockLocationDetected(
    String tripId, {
    required bool detected,
  }) =>
      _trips.doc(tripId).update(<String, Object?>{
        'mockLocationDetected': detected,
      });

  @override
  Future<Trip?> readTrip(String tripId) async {
    final snapshot = await _trips.doc(tripId).get();
    if (!snapshot.exists) return null;
    final data = <String, Object?>{...snapshot.data()!, 'id': snapshot.id};
    return Trip.fromMap(data);
  }

  @override
  Stream<Trip?> watchTripByVanIdAndDate({
    required String vanId,
    required DateTime date,
  }) {
    final dayStart = Timestamp.fromDate(DateTime(date.year, date.month, date.day));
    final dayEnd = Timestamp.fromDate(
      DateTime(date.year, date.month, date.day).add(const Duration(days: 1)),
    );
    final query = _trips
        .where('vanId', isEqualTo: vanId)
        .where('date', isGreaterThanOrEqualTo: dayStart)
        .where('date', isLessThan: dayEnd);
    return query.snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      final data = <String, Object?>{...doc.data(), 'id': doc.id};
      return Trip.fromMap(data);
    });
  }

  @override
  Stream<List<Trip>> watchRecentTrips({
    required String vanId,
    required DateTime asOfDate,
    int limit = 30,
  }) {
    // History includes TODAY (WF-22's "Today" row): the open trip shows
    // as "running", a just-ended trip as completed/partly-done.
    final after = Timestamp.fromDate(
      DateTime(asOfDate.year, asOfDate.month, asOfDate.day)
          .add(const Duration(days: 1)),
    );
    final query = _trips
        .where('vanId', isEqualTo: vanId)
        .where('date', isLessThan: after)
        .orderBy('date', descending: true)
        .limit(limit);
    return query.snapshots().map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = <String, Object?>{...doc.data(), 'id': doc.id};
            return Trip.fromMap(data);
          }).toList(),
        );
  }
}
