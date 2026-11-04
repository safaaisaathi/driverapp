import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/ist_clock.dart';
import '../../models/models.dart';
import '../trips_repository.dart';

/// Firestore-backed [TripsRepository] (CHG-0003, CHG-0005).
///
/// Reads only, plus the trail chunk writes. Trip creation, ward marks and the
/// shift close are callables (`startShift`, `markWardDone`, `endShift`); this
/// repository cannot write them, by contract and by rules.
final class FirestoreTripsRepository implements TripsRepository {
  FirestoreTripsRepository(this._db);

  final FirebaseFirestore _db;

  /// Where the next chunk of each touched trip starts (`chunk` = the next
  /// document id, `points` = how many points the trip's trail already has).
  /// Seeded from the last chunk on first use, so a restart or a re-attach
  /// never reuses an index.
  final Map<String, ({int chunk, int points})> _trailCursor = {};

  CollectionReference<Map<String, Object?>> get _trips =>
      _db.collection('trips');

  CollectionReference<Map<String, Object?>> _trail(String tripId) =>
      _trips.doc(tripId).collection('trail');

  @override
  Future<void> appendGpsTrail(String tripId, List<GpsPoint> points) async {
    if (points.isEmpty) return;
    final trail = _trail(tripId);
    var cursor = _trailCursor[tripId] ?? await _readTrailCursor(trail);
    for (var offset = 0; offset < points.length; offset += trailChunkMaxPoints) {
      final end = offset + trailChunkMaxPoints;
      final slice = points.sublist(
        offset,
        end > points.length ? points.length : end,
      );
      await trail.doc('${cursor.chunk}').set(<String, Object?>{
        'points': slice.map((point) => point.toMap()).toList(),
        'from': cursor.points,
        'to': cursor.points + slice.length,
      });
      cursor = (chunk: cursor.chunk + 1, points: cursor.points + slice.length);
    }
    _trailCursor[tripId] = cursor;
  }

  /// The last chunk by `to` (the highest global index), or the start.
  Future<({int chunk, int points})> _readTrailCursor(
    CollectionReference<Map<String, Object?>> trail,
  ) async {
    final last = await trail
        .orderBy('to', descending: true)
        .limit(1)
        .get();
    if (last.docs.isEmpty) return (chunk: 0, points: 0);
    final doc = last.docs.first;
    final to = doc.data()['to'];
    final index = int.tryParse(doc.id);
    return (
      chunk: (index ?? 0) + 1,
      points: to is int ? to : 0,
    );
  }

  @override
  Future<Trip?> readTrip(String tripId) async {
    final snapshot = await _trips.doc(tripId).get();
    if (!snapshot.exists) return null;
    final data = <String, Object?>{...snapshot.data()!, 'id': snapshot.id};
    return Trip.fromMap(data);
  }

  @override
  Stream<Trip?> watchTrip(String tripId) =>
      _trips.doc(tripId).snapshots().map((snapshot) {
        if (!snapshot.exists) return null;
        final data = <String, Object?>{...snapshot.data()!, 'id': snapshot.id};
        return Trip.fromMap(data);
      });

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
