import 'dart:async';

import 'package:driverapp/core/contract/reason_codes.dart';
import 'package:driverapp/core/contract/shift_gateway.dart';
import 'package:driverapp/core/contract/tracking_gateway.dart';
import 'package:driverapp/core/domain/ist_clock.dart';
import 'package:driverapp/core/identity/install_id.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repositories.dart';

/// In-memory implementations of the repository interfaces (spec seam 1) plus
/// the two callable seams (CHG-0003).
///
/// Feature tests override the provider wiring with these:
///
/// ```dart
/// vansRepositoryProvider.overrideWithValue(FakeVansRepository(...))
/// shiftGatewayProvider.overrideWithValue(FakeShiftGateway(...))
/// ```
///
/// Observable behavior mirrors the Firestore implementations (createdAt-
/// descending notice order, day-bounded complaint queries, trail chunking)
/// without any Firebase. Copies are made through `toMap` → `fromMap` so the
/// fakes also keep exercising the model round-trip path.
///
/// The trip and shift writes are the SERVER's now: [FakeShiftGateway] plays
/// that role against the same in-memory maps, so a flow test sees exactly
/// what a real callable would leave behind.


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

  /// Test-only server simulation: `startShift`/`endShift` set and clear the
  /// van's marker. Not part of [VansRepository] any more (CHG-0003).
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

  /// Trail chunks per trip id, in write order (`trailChunk.schema.json`).
  final Map<String, List<FakeTrailChunk>> trailChunks = {};

  final _changes = StreamController<void>.broadcast();

  /// Test-only server simulation: `startShift` creates the trip and
  /// `markWardDone` appends one entry. Not part of [TripsRepository] any
  /// more (CHG-0003): the app cannot write a trip directly.
  void seedTrip(Trip trip) {
    trips[trip.id] = trip;
    _changes.add(null);
  }

  /// Test-only server simulation: `markWardDone` appends the entry.
  void appendWardDoneTo(String tripId, WardDone entry) {
    final data = _require(tripId).toMap();
    data['wardsDone'] = <Object?>[
      ...(data['wardsDone'] as List<Object?>? ?? const <Object?>[]),
      entry.toMap(),
    ];
    trips[tripId] = Trip.fromMap(data);
    _changes.add(null);
  }

  /// Test-only server simulation: `endShift` stamps `endedAt`.
  void markEnded(String tripId, DateTime endedAt) {
    final data = _require(tripId).toMap()
      ..['endedAt'] = dateTimeToDocTime(endedAt);
    trips[tripId] = Trip.fromMap(data);
    _changes.add(null);
  }

  /// Test-only server simulation: the OFFICE (or a function) sets the
  /// mock-location latch. The driver app itself can no longer write it
  /// (CHG-0003; `trips` is server-owned).
  void setMockLocationDetected(String tripId, {required bool detected}) {
    final data = _require(tripId).toMap()
      ..['mockLocationDetected'] = detected;
    trips[tripId] = Trip.fromMap(data);
    _changes.add(null);
  }

  @override
  Future<void> appendGpsTrail(String tripId, List<GpsPoint> points) async {
    if (points.isEmpty) return;
    _require(tripId);
    final chunks = trailChunks.putIfAbsent(tripId, () => []);
    var cursor = chunks.isEmpty ? 0 : chunks.last.to;
    for (var offset = 0; offset < points.length; offset += trailChunkMaxPoints) {
      final end = offset + trailChunkMaxPoints;
      final slice = points.sublist(
        offset,
        end > points.length ? points.length : end,
      );
      chunks.add(
        FakeTrailChunk(
          points: List.unmodifiable(slice),
          from: cursor,
          to: cursor + slice.length,
        ),
      );
      cursor += slice.length;
    }
    // Test convenience only: the fake also keeps the legacy aggregate so
    // trail assertions in engine tests stay readable. The real repository
    // writes chunks and nothing else.
    final data = _require(tripId).toMap();
    data['gpsTrail'] = <Object?>[
      ...(data['gpsTrail'] as List<Object?>? ?? const <Object?>[]),
      ...points.map((point) => point.toMap()).cast<Object?>(),
    ];
    trips[tripId] = Trip.fromMap(data);
    _changes.add(null);
  }

  @override
  Future<Trip?> readTrip(String tripId) async => trips[tripId];

  @override
  Stream<Trip?> watchTrip(String tripId) {
    late StreamController<Trip?> controller;
    late StreamSubscription<void> changesSub;
    controller = StreamController<Trip?>(
      onListen: () {
        controller.add(trips[tripId]);
        changesSub =
            _changes.stream.listen((_) => controller.add(trips[tripId]));
      },
      onCancel: () => changesSub.cancel(),
    );
    return controller.stream;
  }

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
    // The Firestore live query matches vanId + `date` in the IST day window
    // (issue #15) — a just ended trip still surfaces, so End Shift keeps it
    // watchable. Same tie-break as the real query (issue #25): an open trip
    // beats a closed same-day sibling, otherwise the most recent start.
    final matches = trips.values
        .where(
          (trip) => trip.vanId == vanId && isSameDayIST(trip.date, date),
        )
        .toList()
      ..sort((a, b) {
        final aOpen = a.endedAt == null;
        final bOpen = b.endedAt == null;
        if (aOpen != bOpen) return aOpen ? 1 : -1;
        return a.startedAt.compareTo(b.startedAt);
      });
    return matches.isEmpty ? null : matches.last;
  }

  @override
  Stream<List<Trip>> watchRecentTrips({
    required String vanId,
    required DateTime asOfDate,
    int limit = 30,
  }) {
    late StreamController<List<Trip>> controller;
    late StreamSubscription<void> changesSub;
    List<Trip> latest() {
      // Same IST-day frame as the Firestore query (issue #15).
      final cutoff = istDayWindow(asOfDate).endExclusive;
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

class FakeDriversRepository implements DriversRepository {
  FakeDriversRepository([Iterable<Driver>? seed])
      : drivers = {
          for (final driver in seed ?? const <Driver>[]) driver.id: driver,
        };

  /// Keyed by the normalized driver code (the contract doc id).
  final Map<String, Driver> drivers;

  /// Normalized codes the backing map was consulted with. Empty after a
  /// bad-shape fetch proves the repository normalized before any lookup
  /// (0.16: a bad shape makes no Firestore call).
  final List<String> lookups = [];

  @override
  Future<Driver?> fetchDriver(String rawCode) async {
    final code = normalizeDriverCode(rawCode);
    if (code == null) return null;
    lookups.add(code);
    return drivers[code];
  }
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

/// One `trips/{tripId}/trail/{n}` chunk (`trailChunk.schema.json`).
final class FakeTrailChunk {  const FakeTrailChunk({
    required this.points,
    required this.from,
    required this.to,
  });

  final List<GpsPoint> points;

  final int from;

  final int to;
}

/// The `bindDeviceToVan` + custom-token sign-in seam (CHG-0003).
///
/// A bind failure is scripted with [bindErrors]/[bindFailuresRemaining]; a
/// successful bind returns a token and the caller's binding.
class FakeDriverSessionGateway implements DriverSessionGateway {
  FakeDriverSessionGateway({this.bindingFor});

  /// The binding the callable would mint. Defaults to `van-01` and the code
  /// itself as the driver id.
  final DriverBinding Function(String driverCode)? bindingFor;

  final List<({String driverCode, String installId})> binds = [];

  final List<String> signedInTokens = [];

  ContractException? bindError;

  ContractException? signInError;

  int bindFailuresRemaining = 0;

  @override
  Future<DriverBinding> bindDeviceToVan({
    required String driverCode,
    required String installId,
  }) async {
    binds.add((driverCode: driverCode, installId: installId));
    if (bindFailuresRemaining > 0) {
      bindFailuresRemaining--;
      throw const ContractException(ReasonCode.internal);
    }
    final error = bindError;
    if (error != null) throw error;
    return bindingFor?.call(driverCode) ??
        DriverBinding(
          token: 'token-$driverCode',
          vanId: 'van-01',
          driverId: driverCode,
          claimMode: 'firstClaim',
        );
  }

  @override
  Future<void> signInWithCustomToken(String token) async {
    signedInTokens.add(token);
    final error = signInError;
    if (error != null) throw error;
  }
}

/// Emulates `startShift` / `endShift` / `markWardDone` against the in-memory
/// maps. The behaviour mirrors the platform callables (transaction on the
/// van marker, deterministic trip id, snapshot of the route's wards) so a
/// flow test observes exactly the server's writes.
class FakeShiftGateway implements ShiftGateway {
  FakeShiftGateway({
    required this.trips,
    required this.vans,
    Iterable<Driver>? drivers,
    Map<String, List<String>>? routeWardIds,
    DateTime Function()? clock,
    String Function(String driverId)? tripIdFor,
  })  : drivers = {
          for (final driver in drivers ?? const <Driver>[]) driver.id: driver,
        },
        routeWardIds = routeWardIds ?? const {},
        _clock = clock ?? DateTime.now,
        _tripIdFor = tripIdFor; // ignore: prefer_initializing_formals

  final FakeTripsRepository trips;

  final FakeVansRepository vans;

  final Map<String, Driver> drivers;

  /// `routes/{routeId}.wardIds` snapshots, keyed by route id. Missing routes
  /// fall back to the driver's allotment so a test can seed only one doc.
  final Map<String, List<String>> routeWardIds;

  final DateTime Function() _clock;

  final String Function(String driverId)? _tripIdFor;

  final List<({String driverId, DateTime date})> startCalls = [];

  final List<String> endCalls = [];

  final List<({String tripId, String wardId, bool flagged})> marks = [];

  /// Scripted refusals/outages, checked before the emulated write.
  ContractException? startError;

  ContractException? endError;

  ContractException? markError;

  int startFailuresRemaining = 0;

  int endFailuresRemaining = 0;

  int markFailuresRemaining = 0;

  @override
  Future<ShiftStartResult> startShift({
    required String driverId,
    required DateTime date,
  }) async {
    startCalls.add((driverId: driverId, date: date));
    if (startFailuresRemaining > 0) {
      startFailuresRemaining--;
      throw const ContractException(ReasonCode.internal);
    }
    final error = startError;
    if (error != null) throw error;

    final driver = drivers[driverId];
    if (driver == null) throw const ContractException(ReasonCode.notFound);
    final van = vans.vans[driver.vanId];
    if (van == null) throw const ContractException(ReasonCode.notFound);

    final marker = van.currentTripId;
    if (marker != null && van.status == VanStatus.onShift) {
      final open = trips.trips[marker];
      if (open == null) throw const ContractException(ReasonCode.staleMarker);
      if (open.driverId != driverId) {
        throw const ContractException(ReasonCode.vanHeldByAnotherDriver);
      }
      if (open.vanId != driver.vanId) {
        throw const ContractException(ReasonCode.staleMarker);
      }
      return ShiftStartResult(
        token: 'token-$driverId-$marker',
        tripId: marker,
        vanId: driver.vanId,
      );
    }

    final now = _clock();
    final dayKey = todayIsoIST(now);
    final tripId = _tripIdFor?.call(driverId) ?? '${driverId}_$dayKey';
    final wardIds = routeWardIds[driver.routeId] ?? driver.wardIds;
    trips.seedTrip(
      Trip(
        id: tripId,
        vanId: driver.vanId,
        routeId: driver.routeId,
        driverId: driver.id,
        wardIds: wardIds,
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
      token: 'token-$driverId-$tripId',
      tripId: tripId,
      vanId: driver.vanId,
    );
  }

  @override
  Future<DateTime> endShift(String tripId) async {
    endCalls.add(tripId);
    if (endFailuresRemaining > 0) {
      endFailuresRemaining--;
      throw const ContractException(ReasonCode.internal);
    }
    final error = endError;
    if (error != null) throw error;
    final trip = trips.trips[tripId];
    if (trip == null) throw const ContractException(ReasonCode.notFound);

    final endedAt = _clock();
    trips.markEnded(tripId, endedAt);
    final van = vans.vans[trip.vanId];
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
    marks.add((tripId: tripId, wardId: wardId, flagged: flagged));
    if (markFailuresRemaining > 0) {
      markFailuresRemaining--;
      throw const ContractException(ReasonCode.internal);
    }
    final error = markError;
    if (error != null) throw error;
    if (!trips.trips.containsKey(tripId)) {
      throw const ContractException(ReasonCode.notFound);
    }
    trips.appendWardDoneTo(
      tripId,
      WardDone(wardId: wardId, doneAt: _clock(), flagged: flagged),
    );
  }
}


/// In-memory `flagMockLocation` seam (CHG-0017): records every call and can
/// script outages. The durable trip field is the server's write, so this fake
/// does not mutate the trip doc.
class FakeTrackingGateway implements TrackingGateway {
  final List<String> mockFlagCalls = [];

  /// Every attempt, including the ones that failed.
  int attempts = 0;

  /// When > 0, the next calls fail and decrement this counter.
  int failuresRemaining = 0;

  /// A scripted refusal checked before the call is recorded as a success.
  ContractException? error;

  @override
  Future<MockLocationFlag> flagMockLocation(String tripId) async {
    attempts++;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw const ContractException(ReasonCode.offline);
    }
    final scripted = error;
    if (scripted != null) throw scripted;
    mockFlagCalls.add(tripId);
    return const MockLocationFlag(flagged: true);
  }
}

/// In-memory `installId` seam: a stable id, never a platform channel.
class FakeInstallIdStore implements InstallIdStore {
  FakeInstallIdStore([this.id = 'test-install-id']);

  final String id;

  int reads = 0;

  @override
  Future<String> readOrCreate() async {
    reads++;
    return id;
  }
}
