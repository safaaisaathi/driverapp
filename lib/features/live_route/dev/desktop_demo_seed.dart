/// DESKTOP-PREVIEW SEED for the live-route demo (`dev_live_route.dart`).
///
/// The desktop host has no Firebase plugins, so the Firestore-backed
/// repositories degrade every D2 flow to its error state and the preview
/// window shows nothing useful. This file implements the SAME repository
/// interfaces (`core/repositories`) with tiny in-memory stores — no
/// contract fields renamed, added, or removed (these are dev/demo doubles,
/// not schema).
///
/// Deleted at ticket 14 together with the dev entrypoints (GLOSSARY bag).
/// On the Android-device path the real spine stays in charge — these
/// doubles are only ever wired inside `dev_live_route.dart`'s container.
///
/// Seeded world (stable for demo checks):
/// - `vans/van-01` on `routes/route-01` (3 wards around Ahmedabad), on
///   shift, with an open trip `dev-trip-1` dated TODAY (so D2's own-today
///   watch finds it and ticket 07's Mark Ward Done can append).
/// - two notices: one `all` (unread on arrival) and one aimed at the van.
/// - two `missed_collection` complaints for today's wards (D4 Pending
///   Reports): ward-1 `received`, ward-2 `assigned`.
library;

import 'dart:async';

import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repositories.dart';

/// Ids the demo world is seeded with (mirror the emulator seed naming so
/// the same screen flows run on device later).
const String devSeedVanId = 'van-01';
const String devSeedRouteId = 'route-01';
const String devSeedTripId = 'dev-trip-1';

/// Coordinates the demo world lives in (Ahmedabad). The van marker starts
/// here; the wards fan out around it so the D2 map has something to follow
/// and zoom to.
const double devSeedVanLat = 23.0300;
const double devSeedVanLng = 72.5800;

/// Broadcast-ish store: emits the current snapshot to every subscriber
/// immediately (the Firestore spine does the same — late listeners do not
/// hang on an empty stream) and re-emits on every mutation.
class _MutableStream<T> {
  _MutableStream(this._latest);

  T _latest;
  final StreamController<T> _controller = StreamController<T>.broadcast();

  /// Late subscribers get the CURRENT value first, then every mutation.
  Stream<T> get stream async* {
    yield _latest;
    yield* _controller.stream;
  }

  T get value => _latest;

  void set(T next) {
    _latest = next;
    _controller.add(next);
  }
}

/// ---------------------------------------------------------------------------
/// Vans (in memory)
/// ---------------------------------------------------------------------------

class DevVansRepository implements VansRepository {
  final Map<String, _MutableStream<Van?>> _vans = {};

  void seedVan(Van van) => _vans[van.id] = _MutableStream<Van?>(van);

  _MutableStream<Van?> _store(String vanId) => _vans[vanId]!;

  @override
  Future<List<Van>> readVans() async => [
    for (final store in _vans.values) store.value!,
  ];

  @override
  Stream<Van?> watchVan(String vanId) => _store(vanId).stream;

  @override
  Future<void> updateLastLocation({
    required String vanId,
    required double lat,
    required double lng,
    required double speedKmph,
    DateTime? updatedAt,
  }) async {
    final van = _store(vanId).value!;
    _store(vanId).set(
      Van(
        id: van.id,
        plateNo: van.plateNo,
        routeId: van.routeId,
        status: van.status,
        lastLocation: VanLastLocation(
          lat: lat,
          lng: lng,
          speedKmph: speedKmph,
          updatedAt: updatedAt ?? DateTime.now(),
        ),
        currentTripId: van.currentTripId,
        batteryPct: van.batteryPct,
      ),
    );
  }

  @override
  Future<void> updateStatus(String vanId, VanStatus status) async {
    final van = _store(vanId).value!;
    _store(vanId).set(
      Van(
        id: van.id,
        plateNo: van.plateNo,
        routeId: van.routeId,
        status: status,
        lastLocation: van.lastLocation,
        currentTripId: van.currentTripId,
        batteryPct: van.batteryPct,
      ),
    );
  }

  @override
  Future<void> updateBatteryPct(String vanId, int batteryPct) async {
    final van = _store(vanId).value!;
    _store(vanId).set(
      Van(
        id: van.id,
        plateNo: van.plateNo,
        routeId: van.routeId,
        status: van.status,
        lastLocation: van.lastLocation,
        currentTripId: van.currentTripId,
        batteryPct: batteryPct,
      ),
    );
  }

  @override
  Future<Van?> readVan(String vanId) async => _store(vanId).value;

  @override
  Future<void> updateCurrentTripId(String vanId, String? tripId) async {
    final van = _store(vanId).value!;
    _store(vanId).set(
      Van(
        id: van.id,
        plateNo: van.plateNo,
        routeId: van.routeId,
        status: van.status,
        lastLocation: van.lastLocation,
        currentTripId: tripId,
        batteryPct: van.batteryPct,
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Trips (in memory)
/// ---------------------------------------------------------------------------

class DevTripsRepository implements TripsRepository {
  final Map<String, _MutableStream<Trip?>> _trips = {};

  void seedTrip(Trip trip) => _trips[trip.id] = _MutableStream<Trip?>(trip);

  _MutableStream<Trip?> _store(String tripId) => _trips[tripId]!;

  void _mutate(Trip trip) => _store(trip.id).set(trip);

  Trip _withFields(
    Trip trip, {
    List<WardDone>? wardsDone,
    List<GpsPoint>? gpsTrail,
    bool? mockLocationDetected,
  }) => Trip(
    id: trip.id,
    vanId: trip.vanId,
    routeId: trip.routeId,
    date: trip.date,
    startedAt: trip.startedAt,
    endedAt: trip.endedAt,
    wardsDone: wardsDone ?? trip.wardsDone,
    alertedWardIds: trip.alertedWardIds,
    gpsTrail: gpsTrail ?? trip.gpsTrail,
    mockLocationDetected: mockLocationDetected ?? trip.mockLocationDetected,
  );

  @override
  Future<Trip> createTrip(Trip trip) async {
    seedTrip(trip);
    return trip;
  }

  @override
  Future<void> appendWardDone(String tripId, WardDone entry) async {
    final trip = _store(tripId).value!;
    _mutate(_withFields(trip, wardsDone: [...trip.wardsDone, entry]));
  }

  @override
  Future<void> appendGpsTrail(String tripId, List<GpsPoint> points) async {
    final trip = _store(tripId).value!;
    _mutate(_withFields(trip, gpsTrail: [...trip.gpsTrail, ...points]));
  }

  @override
  Future<void> setEndedAt(String tripId, DateTime endedAt) async {
    final trip = _store(tripId).value!;
    _mutate(
      Trip(
        id: trip.id,
        vanId: trip.vanId,
        routeId: trip.routeId,
        date: trip.date,
        startedAt: trip.startedAt,
        endedAt: endedAt,
        wardsDone: trip.wardsDone,
        alertedWardIds: trip.alertedWardIds,
        gpsTrail: trip.gpsTrail,
        mockLocationDetected: trip.mockLocationDetected,
      ),
    );
  }

  @override
  Future<void> setMockLocationDetected(
    String tripId, {
    required bool detected,
  }) async {
    final trip = _store(tripId).value!;
    _mutate(_withFields(trip, mockLocationDetected: detected));
  }

  @override
  Future<Trip?> readTrip(String tripId) async => _trips[tripId]?.value;

  @override
  Stream<Trip?> watchTripByVanIdAndDate({
    required String vanId,
    required DateTime date,
  }) async* {
    // Providers pass the LOCAL calendar day (ruling 20 — never a ruling-9
    // instant); the seed builds its trip date the same way (see
    // [buildDevTrip]), so plain field equality is the correct match.
    final store = _trips.values
        .where(
          (store) =>
              store.value?.vanId == vanId && _sameDay(store.value!.date, date),
        )
        .firstOrNull;
    if (store == null) {
      yield null;
      return;
    }
    yield* store.stream;
  }

  @override
  Stream<List<Trip>> watchRecentTrips({
    required String vanId,
    required DateTime asOfDate,
    int limit = 30,
  }) async* {
    // Same local-day matching rule as watchTripByVanIdAndDate; history
    // INCLUDES today (WF-22's "Today" row) — a still open trip shows as
    // "running". Newest first.
    final cutoff =
        DateTime(asOfDate.year, asOfDate.month, asOfDate.day)
            .add(const Duration(days: 1));
    final recent =
        _trips.values.map((store) => store.value).whereType<Trip>().where(
              (trip) => trip.vanId == vanId && trip.date.isBefore(cutoff),
            ).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    yield recent.take(limit).toList();
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// ---------------------------------------------------------------------------
/// Routes + Wards (in memory)
/// ---------------------------------------------------------------------------

class DevRoutesRepository implements RoutesRepository {
  final Map<String, RouteModel> _routes = {};

  void seedRoute(RouteModel route) => _routes[route.id] = route;

  @override
  Future<RouteModel?> readRoute(String routeId) async => _routes[routeId];
}

class DevWardsRepository implements WardsRepository {
  final Map<String, Ward> _wards = {};

  void seedWard(Ward ward) => _wards[ward.id] = ward;

  @override
  Future<List<Ward>> readWardsByIds(List<String> ids) async => [
    for (final id in ids) _wards[id]!,
  ];

  @override
  Stream<List<Ward>> watchRouteWards(String routeId) async* {
    final routeWards = [
      for (final ward in _wards.values)
        if (ward.routeId == routeId) ward,
    ];
    yield routeWards;
  }
}

/// ---------------------------------------------------------------------------
/// Notices (in memory)
/// ---------------------------------------------------------------------------

class DevNoticesRepository implements NoticesRepository {
  final List<Notice> _notices = [];

  void seedNotice(Notice notice) => _notices.add(notice);

  @override
  Stream<List<Notice>> watchNotices({
    required String vanId,
    required List<String> wardIds,
  }) async* {
    // The 0.7 three-target filter, exactly as the Firestore repo does it,
    // newest first (ruling 10).
    final visible =
        _notices
            .where(
              (notice) => switch (notice.targetType) {
                NoticeTargetType.all => true,
                NoticeTargetType.van => notice.targetId == vanId,
                NoticeTargetType.ward => wardIds.contains(notice.targetId),
              },
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    yield List.unmodifiable(visible);
  }
}

/// ---------------------------------------------------------------------------
/// Seed assembly
/// ---------------------------------------------------------------------------

/// A dev trip dated TODAY (local calendar fields — ruling 20) so D2's
/// own-today watch always finds it, whatever day the preview runs on.
Trip buildDevTrip(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final started = today.add(const Duration(hours: 7, minutes: 30));
  return Trip(
    id: devSeedTripId,
    vanId: devSeedVanId,
    routeId: devSeedRouteId,
    date: today,
    startedAt: started,
    endedAt: null,
    wardsDone: const [],
    alertedWardIds: const ['ward-2'],
    gpsTrail: [GpsPoint(lat: devSeedVanLat, lng: devSeedVanLng, t: started)],
    mockLocationDetected: false,
  );
}

/// Every double + seeded doc above, ready to wire into a dev container.
/// In-memory complaints for the demo D4. Watching snapshots the current
/// (filtered) list; every mutation re-emits with the SAME filter applied,
/// so the D4 list reacts live to "Will Revisit" / "Done".
class DevComplaintsRepository implements ComplaintsRepository {
  final Map<String, Complaint> _complaints = {};
  final _streams = <({
    List<String> wardIds,
    DateTime day,
    List<ComplaintStatus> statuses,
    _MutableStream<List<Complaint>> stream,
  })>[];

  void seedComplaint(Complaint c) => _complaints[c.id] = c;

  List<Complaint> _filtered({
    required List<String> wardIds,
    required DateTime day,
    required List<ComplaintStatus> statuses,
  }) {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final active = _complaints.values
        .where(
          (c) =>
              wardIds.contains(c.wardId) &&
              !c.createdAt.isBefore(startOfDay) &&
              c.createdAt.isBefore(endOfDay) &&
              statuses.contains(c.status),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return active;
  }

  @override
  Stream<List<Complaint>> watchMissedCollectionComplaints({
    required List<String> wardIds,
    required DateTime day,
    required List<ComplaintStatus> statuses,
  }) {
    final stream = _MutableStream<List<Complaint>>(
      _filtered(wardIds: wardIds, day: day, statuses: statuses),
    );
    _streams.add((
      wardIds: wardIds,
      day: day,
      statuses: statuses,
      stream: stream,
    ));
    return stream.stream;
  }

  @override
  Future<void> updateStatus(
    String complaintId,
    ComplaintStatus status, {
    DateTime? resolvedAt,
  }) async {
    final current = _complaints[complaintId];
    if (current == null) throw StateError('unknown complaint $complaintId');
    _complaints[complaintId] = Complaint(
      id: current.id,
      ticketId: current.ticketId,
      deviceId: current.deviceId,
      category: current.category,
      photoUrl: current.photoUrl,
      location: current.location,
      wardId: current.wardId,
      createdAt: current.createdAt,
      status: status,
      assignedTo: current.assignedTo,
      escalationLevel: current.escalationLevel,
      resolvedPhotoUrl: current.resolvedPhotoUrl,
      resolvedAt: resolvedAt,
      mergedInto: current.mergedInto,
      note: current.note,
    );
    // Re-emit every active watcher with its own filter (the D4 list reacts
    // live to the actions).
    for (final w in _streams) {
      w.stream.set(
        _filtered(
          wardIds: w.wardIds,
          day: w.day,
          statuses: w.statuses,
        ),
      );
    }
  }
}

class DevDesktopSeed {
  DevDesktopSeed() {
    final now = DateTime.now();

    vans.seedVan(
      Van(
        id: devSeedVanId,
        plateNo: 'GJ-01-V-2201',
        routeId: devSeedRouteId,
        status: VanStatus.onShift,
        lastLocation: VanLastLocation(
          lat: devSeedVanLat,
          lng: devSeedVanLng,
          speedKmph: 12,
          updatedAt: now,
        ),
        currentTripId: devSeedTripId,
        batteryPct: 84,
      ),
    );

    trips.seedTrip(buildDevTrip(now));

    routes.seedRoute(
      RouteModel(
        id: devSeedRouteId,
        name: 'West Loop',
        wardIds: const ['ward-1', 'ward-2', 'ward-3'],
        scheduledStartTime: '07:30',
      ),
    );

    wards.seedWard(
      Ward(
        id: 'ward-1',
        name: 'Ghatlodia',
        nameGu: 'ઘાટલોડિયા',
        code: 'W-01',
        type: WardType.urban,
        center: LocationPoint(lat: 23.0342, lng: 72.5701),
        radiusM: 250,
        routeId: devSeedRouteId,
        inspectorId: 'staff-1',
        escalationTo: 'staff-9',
      ),
    );
    wards.seedWard(
      Ward(
        id: 'ward-2',
        name: 'Vastrapur',
        nameGu: 'વાસ્તાપુર',
        code: 'W-02',
        type: WardType.urban,
        center: LocationPoint(lat: 23.0280, lng: 72.5800),
        radiusM: 250,
        routeId: devSeedRouteId,
        inspectorId: 'staff-2',
        escalationTo: 'staff-9',
      ),
    );
    wards.seedWard(
      Ward(
        id: 'ward-3',
        name: 'Bodakdev',
        nameGu: 'બોડકદેવ',
        code: 'W-03',
        type: WardType.urban,
        center: LocationPoint(lat: 23.0210, lng: 72.5900),
        radiusM: 250,
        routeId: devSeedRouteId,
        inspectorId: 'staff-3',
        escalationTo: 'staff-9',
      ),
    );

    notices.seedNotice(
      Notice(
        id: 'notice-1',
        targetType: NoticeTargetType.all,
        targetId: '',
        message: 'Ring-road stretch is water-logged; use the service lane.',
        createdAt: now.subtract(const Duration(hours: 1)),
        createdBy: 'staff-9',
      ),
    );
    notices.seedNotice(
      Notice(
        id: 'notice-2',
        targetType: NoticeTargetType.van,
        targetId: devSeedVanId,
        message: 'Maintenance: your van is due for the evening check-up.',
        createdAt: now.subtract(const Duration(hours: 4)),
        createdBy: 'staff-9',
      ),
    );

    complaints.seedComplaint(
      Complaint(
        id: 'complaint-1',
        ticketId: 'PMH-20261025-0101',
        deviceId: 'user-1',
        category: ComplaintCategory.missedCollection,
        photoUrl: null,
        location: null,
        wardId: 'ward-1',
        createdAt: now.subtract(const Duration(hours: 3)),
        status: ComplaintStatus.received,
        assignedTo: null,
        escalationLevel: 0,
        resolvedPhotoUrl: null,
        resolvedAt: null,
        mergedInto: null,
        note: 'Bin at gate 3 was not emptied.',
      ),
    );
    complaints.seedComplaint(
      Complaint(
        id: 'complaint-2',
        ticketId: 'PMH-20261025-0102',
        deviceId: 'user-2',
        category: ComplaintCategory.missedCollection,
        photoUrl: null,
        location: null,
        wardId: 'ward-2',
        createdAt: now.subtract(const Duration(hours: 1, minutes: 20)),
        status: ComplaintStatus.received,
        assignedTo: null,
        escalationLevel: 0,
        resolvedPhotoUrl: null,
        resolvedAt: null,
        mergedInto: null,
        note: 'Morning collection missed on the ring road.',
      ),
    );
  }

  final DevVansRepository vans = DevVansRepository();
  final DevTripsRepository trips = DevTripsRepository();
  final DevRoutesRepository routes = DevRoutesRepository();
  final DevWardsRepository wards = DevWardsRepository();
  final DevNoticesRepository notices = DevNoticesRepository();
  final DevComplaintsRepository complaints = DevComplaintsRepository();
}
