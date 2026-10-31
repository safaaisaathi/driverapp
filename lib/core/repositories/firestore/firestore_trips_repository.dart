import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/ist_clock.dart';
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
    // IST-day frame (issue #15): the writer stores `trips.date` as the IST
    // midnight instant, so the window must be built in the same frame. Using
    // the device's local calendar fields put a non-IST phone on the wrong day.
    final window = istDayWindow(date);
    final query = _trips
        .where('vanId', isEqualTo: vanId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(window.start))
        .where('date', isLessThan: Timestamp.fromDate(window.endExclusive));
    return query.snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final trips = snapshot.docs
          .map((doc) => Trip.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
      // Contract: "the open (or just-closed) trip". Two trips can share an
      // IST day (a shift ended, then a new one started), and docs come back
      // in document-id order — taking `.first` once picked the closed
      // sibling and showed its stale done ticks (issue #25). Open wins; among
      // closed trips the most recent start wins.
      trips.sort((a, b) {
        final aOpen = a.endedAt == null;
        final bOpen = b.endedAt == null;
        if (aOpen != bOpen) return aOpen ? -1 : 1;
        return b.startedAt.compareTo(a.startedAt);
      });
      return trips.first;
    });
  }

  @override
  Stream<List<Trip>> watchRecentTrips({
    required String vanId,
    required DateTime asOfDate,
    int limit = 30,
  }) {
    // History includes TODAY (WF-22's "Today" row): the open trip shows
    // as "running", a just-ended trip as completed/partly-done. Bounded in
    // the IST-day frame, like the write side (issue #15).
    final after = istDayWindow(asOfDate).endExclusive;
    final query = _trips
        .where('vanId', isEqualTo: vanId)
        .where('date', isLessThan: Timestamp.fromDate(after))
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
