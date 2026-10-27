import 'dart:async';

import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repositories.dart';

/// In-memory implementations of the six repository interfaces (spec seam 1).
///
/// Feature tests override the provider wiring with these:
///
/// ```dart
/// vansRepositoryProvider.overrideWithValue(FakeVansRepository(...))
/// ```
///
/// Observable behavior mirrors the Firestore implementations (fresh doc id on
/// create, createdAt-descending notice order, day-bounded complaint queries)
/// without any Firebase. Copies are made through `toMap` → `fromMap` so the
/// fakes also keep exercising the model round-trip path.


class FakeVansRepository implements VansRepository {
  FakeVansRepository([Iterable<Van>? seed])
      : vans = {for (final van in seed ?? const <Van>[]) van.id: van};

  /// Keyed by contract doc id; publicly inspectable after writes.
  final Map<String, Van> vans;

  final _changes = StreamController<void>.broadcast();

  @override
  Future<List<Van>> readVans() async => vans.values.toList();

  @override
  Future<Van?> readVan(String vanId) async => vans[vanId];

  @override
  Stream<Van?> watchVan(String vanId) {
    // Controller pattern, not async*: a suspended generator awaiting the
    // broadcast `_changes` stream keeps `pumpEventQueue()` from draining in
    // tests, while controller-based streams act like the real Firestore
    // snapshots stream.
    late StreamController<Van?> controller;
    late StreamSubscription<void> changesSub;
    controller = StreamController<Van?>(
      onListen: () {
        controller.add(vans[vanId]);
        changesSub = _changes.stream.listen((_) => controller.add(vans[vanId]));
      },
      onCancel: () => changesSub.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<void> updateLastLocation({
    required String vanId,
    required double lat,
    required double lng,
    required double speedKmph,
    DateTime? updatedAt,
  }) async {
    final van = _requireVan(vanId);
    // A fake has no server clock; a null updatedAt stands in for the
    // server-timestamp write the Firestore implementation performs.
    final data = van.toMap()
      ..['lastLocation'] = {
        'lat': lat,
        'lng': lng,
        'updatedAt': dateTimeToDocTime(updatedAt ?? DateTime.now()),
        'speedKmph': speedKmph,
      };
    vans[vanId] = Van.fromMap(data);
    _changes.add(null);
  }

  @override
  Future<void> updateStatus(String vanId, VanStatus status) async {
    final data = _requireVan(vanId).toMap()..['status'] = status.value;
    vans[vanId] = Van.fromMap(data);
    _changes.add(null);
  }

  @override
  Future<void> updateBatteryPct(String vanId, int batteryPct) async {
    final data = _requireVan(vanId).toMap()..['batteryPct'] = batteryPct;
    vans[vanId] = Van.fromMap(data);
    _changes.add(null);
  }

  @override
  Future<void> updateCurrentTripId(String vanId, String? tripId) async {
    final data = _requireVan(vanId).toMap()..['currentTripId'] = tripId;
    vans[vanId] = Van.fromMap(data);
    _changes.add(null);
  }

  Van _requireVan(String vanId) {
    final van = vans[vanId];
    if (van == null) {
      throw StateError('No van seeded with id "$vanId" in FakeVansRepository');
    }
    return van;
  }
}

class FakeTripsRepository implements TripsRepository {
  FakeTripsRepository([Iterable<Trip>? seed])
      : trips = {for (final trip in seed ?? const <Trip>[]) trip.id: trip};

  final Map<String, Trip> trips;

  final _changes = StreamController<void>.broadcast();

  int _idCounter = 0;

  @override
  Future<Trip> createTrip(Trip trip) async {
    final data = <String, Object?>{
      ...trip.toMap(),
      'id': 'trip-${_idCounter++}',
    };
    final created = Trip.fromMap(data);
    trips[created.id] = created;
    _changes.add(null);
    return created;
  }

  @override
  Future<void> appendWardDone(String tripId, WardDone entry) async {
    final data = _require(tripId).toMap();
    data['wardsDone'] = <Object?>[
      ...(data['wardsDone'] as List<Object?>? ?? const <Object?>[]),
      entry.toMap(),
    ];
    trips[tripId] = Trip.fromMap(data);
    _changes.add(null);
  }

  @override
  Future<void> appendGpsTrail(String tripId, List<GpsPoint> points) async {
    final data = _require(tripId).toMap();
    data['gpsTrail'] = <Object?>[
      ...(data['gpsTrail'] as List<Object?>? ?? const <Object?>[]),
      // Mirror FieldValue.arrayUnion: the whole batch appended in one write.
      ...points.map((point) => point.toMap()).cast<Object?>(),
    ];
    trips[tripId] = Trip.fromMap(data);
    _changes.add(null);
  }

  @override
  Future<void> setEndedAt(String tripId, DateTime endedAt) async {
    final data = _require(tripId).toMap()..['endedAt'] = dateTimeToDocTime(endedAt);
    trips[tripId] = Trip.fromMap(data);
    _changes.add(null);
  }

  @override
  Future<void> setMockLocationDetected(
    String tripId, {
    required bool detected,
  }) async {
    final data = _require(tripId).toMap()
      ..['mockLocationDetected'] = detected;
    trips[tripId] = Trip.fromMap(data);
    _changes.add(null);
  }

  @override
  Future<Trip?> readTrip(String tripId) async => trips[tripId];

  @override
  Stream<Trip?> watchTripByVanIdAndDate({
    required String vanId,
    required DateTime date,
  }) {
    late StreamController<Trip?> controller;
    late StreamSubscription<void> changesSub;
    controller = StreamController<Trip?>(
      onListen: () {
        controller.add(_latestFor(vanId, date));
        changesSub = _changes.stream
            .listen((_) => controller.add(_latestFor(vanId, date)));
      },
      onCancel: () => changesSub.cancel(),
    );
    return controller.stream;
  }

  Trip? _latestFor(String vanId, DateTime date) {
    // The Firestore live query matches vanId + `date` in [day, day+1) — a just
    // ended trip still surfaces, so End Shift keeps it watchable.
    final matches = trips.values
        .where(
          (trip) => trip.vanId == vanId && _sameDay(trip.date, date),
        )
        .toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return matches.isEmpty ? null : matches.last;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Stream<List<Trip>> watchRecentTrips({
    required String vanId,
    required DateTime asOfDate,
    int limit = 30,
  }) {
    late StreamController<List<Trip>> controller;
    late StreamSubscription<void> changesSub;
    List<Trip> latest() {
      final cutoff =
          DateTime(asOfDate.year, asOfDate.month, asOfDate.day)
              .add(const Duration(days: 1));
      final matches = trips.values
          .where(
            (trip) =>
                trip.vanId == vanId && trip.date.isBefore(cutoff),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return matches.take(limit).toList();
    }

    controller = StreamController<List<Trip>>(
      onListen: () {
        controller.add(latest());
        changesSub =
            _changes.stream.listen((_) => controller.add(latest()));
      },
      onCancel: () => changesSub.cancel(),
    );
    return controller.stream;
  }

  Trip _require(String tripId) {
    final trip = trips[tripId];
    if (trip == null) {
      throw StateError('No trip "$tripId" in FakeTripsRepository');
    }
    return trip;
  }
}

class FakeNoticesRepository implements NoticesRepository {
  FakeNoticesRepository([Iterable<Notice>? seed])
      : notices = {
          for (final notice in seed ?? const <Notice>[]) notice.id: notice,
        };

  final Map<String, Notice> notices;

  final _changes = StreamController<void>.broadcast();

  @override
  Stream<List<Notice>> watchNotices({
    required String vanId,
    required List<String> wardIds,
  }) {
    late StreamController<List<Notice>> controller;
    late StreamSubscription<void> changesSub;
    controller = StreamController<List<Notice>>(
      onListen: () {
        controller.add(_filtered(vanId, wardIds));
        changesSub = _changes.stream
            .listen((_) => controller.add(_filtered(vanId, wardIds)));
      },
      onCancel: () => changesSub.cancel(),
    );
    return controller.stream;
  }

  List<Notice> _filtered(String vanId, List<String> wardIds) {
    final result = notices.values
        .where(
          (notice) => switch (notice.targetType) {
            NoticeTargetType.all => true,
            NoticeTargetType.van => notice.targetId == vanId,
            NoticeTargetType.ward => wardIds.contains(notice.targetId),
          },
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }
}

class FakeComplaintsRepository implements ComplaintsRepository {
  FakeComplaintsRepository([Iterable<Complaint>? seed])
      : complaints = {
          for (final complaint in seed ?? const <Complaint>[])
            complaint.id: complaint,
        };

  final Map<String, Complaint> complaints;

  final _changes = StreamController<void>.broadcast();

  @override
  Stream<List<Complaint>> watchMissedCollectionComplaints({
    required List<String> wardIds,
    required DateTime day,
    required List<ComplaintStatus> statuses,
  }) {
    late StreamController<List<Complaint>> controller;
    late StreamSubscription<void> changesSub;
    controller = StreamController<List<Complaint>>(
      onListen: () {
        controller.add(_filtered(wardIds, day, statuses));
        changesSub = _changes.stream.listen(
          (_) => controller.add(_filtered(wardIds, day, statuses)),
        );
      },
      onCancel: () => changesSub.cancel(),
    );
    return controller.stream;
  }

  List<Complaint> _filtered(
    List<String> wardIds,
    DateTime day,
    List<ComplaintStatus> statuses,
  ) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return complaints.values
        .where(
          (complaint) =>
              complaint.category == ComplaintCategory.missedCollection &&
              wardIds.contains(complaint.wardId) &&
              statuses.contains(complaint.status) &&
              !complaint.createdAt.isBefore(dayStart) &&
              complaint.createdAt.isBefore(dayEnd),
        )
        .toList();
  }

  @override
  Future<void> updateStatus(
    String complaintId,
    ComplaintStatus status, {
    DateTime? resolvedAt,
  }) async {
    final data = _require(complaintId).toMap()
      ..['status'] = status.value
      ..['resolvedAt'] = dateTimeToDocTime(resolvedAt);
    complaints[complaintId] = Complaint.fromMap(data);
    _changes.add(null);
  }

  Complaint _require(String complaintId) {
    final complaint = complaints[complaintId];
    if (complaint == null) {
      throw StateError(
        'No complaint "$complaintId" in FakeComplaintsRepository',
      );
    }
    return complaint;
  }
}

class FakeWardsRepository implements WardsRepository {
  FakeWardsRepository([Iterable<Ward>? seed])
      : wards = {for (final ward in seed ?? const <Ward>[]) ward.id: ward};

  final Map<String, Ward> wards;

  final _changes = StreamController<void>.broadcast();

  @override
  Future<List<Ward>> readWardsByIds(List<String> ids) async =>
      wards.values.where((ward) => ids.contains(ward.id)).toList();

  @override
  Stream<List<Ward>> watchRouteWards(String routeId) {
    late StreamController<List<Ward>> controller;
    late StreamSubscription<void> changesSub;
    controller = StreamController<List<Ward>>(
      onListen: () {
        controller.add(_routeWards(routeId));
        changesSub = _changes.stream
            .listen((_) => controller.add(_routeWards(routeId)));
      },
      onCancel: () => changesSub.cancel(),
    );
    return controller.stream;
  }

  List<Ward> _routeWards(String routeId) => wards.values
      .where((ward) => ward.routeId == routeId)
      .toList()
    ..sort((a, b) => a.id.compareTo(b.id));
}

class FakeRoutesRepository implements RoutesRepository {
  FakeRoutesRepository([Iterable<RouteModel>? seed])
      : routes = {
          for (final route in seed ?? const <RouteModel>[]) route.id: route,
        };

  final Map<String, RouteModel> routes;

  void seedRoute(RouteModel route) => routes[route.id] = route;

  @override
  Future<RouteModel?> readRoute(String routeId) async => routes[routeId];
}
