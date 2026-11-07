/// DESKTOP-PREVIEW SEED for the dev entrypoints (`dev_identity_start.dart`
/// and `dev_flow_preview.dart`).
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
/// doubles are only ever wired inside the dev entrypoints' containers.
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

import 'package:driverapp/core/contract/reason_codes.dart';
import 'package:driverapp/core/contract/shift_gateway.dart';
import 'package:driverapp/core/domain/ist_clock.dart';
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

  /// Dev-only: parks the van idle and drops its open-trip marker, so an
  /// identity preview takes the FRESH start path (Start creates a trip and
  /// writes the 0.16 driver identity). The live-route demo stays seeded
  /// on shift; this is only called from the identity previews.
  void parkAsIdle(String vanId) {
    final van = _store(vanId).value!;
    _store(vanId).set(
      Van(
        id: van.id,
        plateNo: van.plateNo,
        routeId: van.routeId,
        status: VanStatus.idle,
        lastLocation: van.lastLocation,
        currentTripId: null,
        batteryPct: van.batteryPct,
      ),
    );
  }

  _MutableStream<Van?> _store(String vanId) => _vans[vanId]!;

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

  /// Dev-only server simulation: the shift callables own this field in the
  /// real app (CHG-0003). Not part of [VansRepository].
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
    driverId: trip.driverId,
    wardIds: trip.wardIds,
    date: trip.date,
    startedAt: trip.startedAt,
    endedAt: trip.endedAt,
    wardsDone: wardsDone ?? trip.wardsDone,
    alertedWardIds: trip.alertedWardIds,
    gpsTrail: gpsTrail ?? trip.gpsTrail,
    mockLocationDetected: mockLocationDetected ?? trip.mockLocationDetected,
  );

  /// Dev-only server simulation: `startShift` creates the trip. Not part of
  /// [TripsRepository] any more (CHG-0003).
  Future<Trip> createTrip(Trip trip) async {
    seedTrip(trip);
    return trip;
  }

  /// Dev-only server simulation: `markWardDone` appends the entry.
  Future<void> appendWardDone(String tripId, WardDone entry) async {
    final trip = _store(tripId).value!;
    _mutate(_withFields(trip, wardsDone: [...trip.wardsDone, entry]));
  }

  @override
  Future<void> appendGpsTrail(String tripId, List<GpsPoint> points) async {
    final trip = _store(tripId).value!;
    _mutate(_withFields(trip, gpsTrail: [...trip.gpsTrail, ...points]));
  }

  /// Dev-only server simulation: `endShift` stamps `endedAt`.
  Future<void> setEndedAt(String tripId, DateTime endedAt) async {
    final trip = _store(tripId).value!;
    _mutate(
      Trip(
        id: trip.id,
        vanId: trip.vanId,
        routeId: trip.routeId,
        driverId: trip.driverId,
        wardIds: trip.wardIds,
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

  /// Dev-only server simulation: the OFFICE sets the latch. The driver app
  /// can no longer write it (CHG-0003).
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
  Stream<Trip?> watchTrip(String tripId) async* {
    final store = _trips[tripId];
    if (store == null) {
      yield null;
      return;
    }
    yield* store.stream;
  }

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
/// Callable seams (dev doubles)
/// ---------------------------------------------------------------------------

/// Desktop `bindDeviceToVan` + sign-in double: mints a fake token and binds
/// the driver to the seeded van. Nothing leaves the process.
class DevDriverSessionGateway implements DriverSessionGateway {
  const DevDriverSessionGateway({required this.vanIdFor});

  final String Function(String driverCode) vanIdFor;

  @override
  Future<DriverBinding> bindDeviceToVan({
    required String driverCode,
    required String installId,
  }) async =>
      DriverBinding(
        token: 'dev-token-$driverCode',
        vanId: vanIdFor(driverCode),
        driverId: driverCode,
        claimMode: 'firstClaim',
      );

  @override
  Future<void> signInWithCustomToken(String token) async {}
}

/// Desktop `startShift` / `endShift` / `markWardDone` double: writes the same
/// documents the server would, against the in-memory seed.
class DevShiftGateway implements ShiftGateway {
  DevShiftGateway({
    required this.trips,
    required this.vans,
    required this.driverFor,
    required this.routeWardIds,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final DevTripsRepository trips;

  final DevVansRepository vans;

  final Driver? Function(String driverId) driverFor;

  final Map<String, List<String>> routeWardIds;

  final DateTime Function() _clock;

  int _counter = 0;

  @override
  Future<ShiftStartResult> startShift({
    required String driverId,
    required DateTime date,
  }) async {
    final driver = driverFor(driverId);
    if (driver == null) throw const ContractException(ReasonCode.notFound);
    final van = await vans.readVan(driver.vanId);
    if (van == null) throw const ContractException(ReasonCode.notFound);

    final marker = van.currentTripId;
    if (marker != null && van.status == VanStatus.onShift) {
      final open = await trips.readTrip(marker);
      if (open == null) throw const ContractException(ReasonCode.staleMarker);
      if (open.driverId != driverId) {
        throw const ContractException(ReasonCode.vanHeldByAnotherDriver);
      }
      return ShiftStartResult(
        token: 'dev-token-$driverId-$marker',
        tripId: marker,
        vanId: driver.vanId,
      );
    }

    final now = _clock();
    final tripId = 'dev-trip-${++_counter}';
    await trips.createTrip(
      Trip(
        id: tripId,
        vanId: driver.vanId,
        routeId: driver.routeId,
        driverId: driver.id,
        wardIds: routeWardIds[driver.routeId] ?? driver.wardIds,
        date: utcStartOfIstDay(now),
        startedAt: now,
        endedAt: null,
        wardsDone: const <WardDone>[],
        alertedWardIds: const <String>[],
        gpsTrail: const <GpsPoint>[],
        mockLocationDetected: false,
      ),
    );
    await vans.updateCurrentTripId(driver.vanId, tripId);
    await vans.updateStatus(driver.vanId, VanStatus.onShift);
    return ShiftStartResult(
      token: 'dev-token-$driverId-$tripId',
      tripId: tripId,
      vanId: driver.vanId,
    );
  }

  @override
  Future<DateTime> endShift(String tripId) async {
    final trip = await trips.readTrip(tripId);
    if (trip == null) throw const ContractException(ReasonCode.notFound);
    final endedAt = _clock();
    await trips.setEndedAt(tripId, endedAt);
    final van = await vans.readVan(trip.vanId);
    if (van != null && van.currentTripId == tripId) {
      await vans.updateCurrentTripId(trip.vanId, null);
      await vans.updateStatus(trip.vanId, VanStatus.idle);
    }
    return endedAt;
  }

  @override
  Future<void> markWardDone({
    required String tripId,
    required String wardId,
    required bool flagged,
  }) async {
    if (await trips.readTrip(tripId) == null) {
      throw const ContractException(ReasonCode.notFound);
    }
    await trips.appendWardDone(
      tripId,
      WardDone(wardId: wardId, doneAt: _clock(), flagged: flagged),
    );
  }
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

  /// In-memory receipts: the dev/demo seed has no backend, so the session
  /// keeps the dot behaviour it always had (CHG-0018 writes nothing here).
  final Map<String, Set<String>> _receipts = {};

  @override
  Future<Set<String>> readReceipts({
    required String driverCode,
    required Iterable<String> noticeIds,
  }) async => <String>{
    for (final noticeId in noticeIds)
      if (_receipts[noticeId]?.contains(driverCode) ?? false) noticeId,
  };

  @override
  Future<void> writeReceipt({
    required String driverCode,
    required String noticeId,
  }) async => (_receipts[noticeId] ??= <String>{}).add(driverCode);
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
    // The plain live-route seed has no driver behind it and predates the
    // 0.16 contract, so D2 falls back to `routes.wardIds` for the order.
    driverId: '',
    wardIds: const [],
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
