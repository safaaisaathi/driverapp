import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:driverapp/core/domain/ist_clock.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repositories.dart';
import 'package:flutter_test/flutter_test.dart';

import '../models/sample_maps.dart';
import 'fake_repositories.dart';

/// Fakes at spec seam 1: repository behavior tests target contract semantics
/// only — no live Firebase, no emulator (spec Testing Decisions; the Firestore
/// implementations are exercised at the integration checkpoints).
void main() {
  group('FakeVansRepository', () {
    late FakeVansRepository repo;
    late Van van;

    setUp(() {
      van = Van.fromMap(vanDocMap());
      repo = FakeVansRepository([van, Van.fromMap(vanDocMap(id: 'van-02'))]);
    });

    test('implements the seam interface so ProviderScope overrides type-check',
        () {
      expect(repo, isA<VansRepository>());
    });

    test(
        'readVans returns the list ({id, plateNo, routeId, status, lastLocation})',
        () async {
      final vans = await repo.readVans();
      expect(vans.map((element) => element.id), const ['van-01', 'van-02']);
      expect(vans.first.plateNo, 'GJ-05-AB-1234');
      expect(vans.first.routeId, 'route-01');
      expect(vans.first.status, VanStatus.onShift);
      expect(vans.first.lastLocation, isNotNull);
    });

    test('watchVan first emits the seeded van, then changes after updates',
        () async {
      final events = <Van?>[];
      final subscription = repo.watchVan('van-01').listen(events.add);
      await pumpEventQueue();
      expect(events, hasLength(1));
      expect(events.single!.id, 'van-01');

      await repo.updateStatus('van-01', VanStatus.idle);
      await pumpEventQueue();
      expect(events, hasLength(2));
      expect(events.last!.status, VanStatus.idle);

      await repo.updateBatteryPct('van-01', 18);
      await pumpEventQueue();
      expect(events, hasLength(3));
      expect(events.last!.batteryPct, 18);
      await subscription.cancel();
    });

    test(
        'updateLastLocation rewrites the whole {lat,lng,updatedAt,speedKmph} object',
        () async {
      final updated = DateTime(2026, 10, 20, 8, 15, 41, 6);
      await repo.updateLastLocation(
        vanId: 'van-01',
        lat: 22.7766,
        lng: 73.7099,
        speedKmph: 14,
        updatedAt: updated,
      );
      final location = repo.vans['van-01']!.lastLocation!;
      expect(location.lat, 22.7766);
      expect(location.lng, 73.7099);
      expect(location.speedKmph, 14);
      expect(location.updatedAt, updated);
      // Everything else on the van doc is preserved.
      expect(repo.vans['van-01']!.status, VanStatus.onShift);
      expect(repo.vans['van-01']!.plateNo, 'GJ-05-AB-1234');
    });
  });

  group('FakeTripsRepository', () {
    late FakeTripsRepository repo;
    late Trip trip;

    setUp(() {
      trip = Trip.fromMap(tripDocMapOpen());
      repo = FakeTripsRepository([trip]);
    });

    test('createTrip assigns a fresh contract id and stores the trip',
        () async {
      final created = await repo.createTrip(trip);
      expect(created.id, isNot('trip-01')); // fresh id, not the seed's
      expect(created.id, isNotEmpty);
      expect(created.vanId, 'van-01');
      expect(created.routeId, 'route-01');
      expect(repo.trips.containsKey(created.id), isTrue);

      final second = await repo.createTrip(trip);
      expect(second.id, isNot(created.id)); // resume-never-duplicate seam
    });

    test('watchTripByVanIdAndDate streams the fresh trip through updates',
        () async {
      final created = await repo.createTrip(trip);
      final events = <Trip?>[];
      final subscription = repo
          .watchTripByVanIdAndDate(vanId: 'van-01', date: DateTime(2026, 10, 20))
          .listen(events.add);
      await pumpEventQueue();
      expect(events, hasLength(1));
      expect(events.single!.id, created.id);
      expect(events.single!.endedAt, isNull); // tripDocMapOpen shape

      await repo.appendWardDone(
        created.id,
        WardDone(
          wardId: 'ward-02',
          doneAt: DateTime(2026, 10, 20, 9, 5),
          flagged: true, // Mark Ward Done outside radius → Flagged (Glossary)
        ),
      );
      await pumpEventQueue();
      expect(events, hasLength(2));
      expect(
        events.last!.wardsDone.map((entry) => entry.wardId),
        contains('ward-02'),
      );
      await subscription.cancel();
    });

    test('watchTripByVanIdAndDate matches the IST day, not the phone zone '
        '(issue #15)', () async {
      // `trips.date` is the IST-midnight instant: 2026-11-01 IST starts at
      // 18:30 UTC on Oct 31. A query made late on that IST day (17:30 UTC on
      // Nov 1) is the SAME IST day, but a different LOCAL day on any zone at
      // or west of UTC, which is exactly where the local-field day match
      // dropped today's trip.
      final istDay = DateTime.utc(2026, 10, 31, 18, 30);
      final lateInThatIstDay = DateTime.utc(2026, 11, 1, 17, 30);
      expect(istDayWindow(lateInThatIstDay).start, istDay);
      final seeded = FakeTripsRepository([
        Trip.fromMap({...tripDocMapOpen(), 'date': ts(istDay)}),
      ]);

      final events = <Trip?>[];
      final subscription = seeded
          .watchTripByVanIdAndDate(vanId: 'van-01', date: lateInThatIstDay)
          .listen(events.add);
      await pumpEventQueue();
      expect(events.single?.id, 'trip-01');
      await subscription.cancel();
    });

    test('watchRecentTrips ends at the next IST midnight, never including '
        'the next day (issue #15)', () async {
      final novFirst = DateTime.utc(2026, 10, 31, 18, 30); // 00:00 IST Nov 1
      final novSecond = DateTime.utc(2026, 11, 1, 18, 30); // 00:00 IST Nov 2
      final seeded = FakeTripsRepository([
        Trip.fromMap({...tripDocMapOpen(id: 'trip-01'), 'date': ts(novFirst)}),
        Trip.fromMap({...tripDocMapOpen(id: 'trip-02'), 'date': ts(novSecond)}),
      ]);

      final events = <List<Trip>>[];
      final subscription = seeded
          .watchRecentTrips(
            vanId: 'van-01',
            asOfDate: DateTime.utc(2026, 11, 1, 17, 30),
          )
          .listen(events.add);
      await pumpEventQueue();
      expect(
        events.single.map((trip) => trip.id),
        ['trip-01'],
        reason: 'the next IST day is outside the history window',
      );
      await subscription.cancel();
    });

    test('appendWardDone appends in order and keeps flagged semantics', () async {
      final created = await repo.createTrip(trip);
      await repo.appendWardDone(
        created.id,
        WardDone(
          wardId: 'ward-02',
          doneAt: DateTime(2026, 10, 20, 9, 5),
          flagged: true,
        ),
      );
      final wardsDone = repo.trips[created.id]!.wardsDone;
      // tripDocMapOpen seeds two entries; the append lands after them.
      expect(wardsDone, hasLength(3));
      expect(
        wardsDone.last,
        WardDone(
          wardId: 'ward-02',
          doneAt: DateTime(2026, 10, 20, 9, 5),
          flagged: true,
        ),
      );

      await repo.appendGpsTrail(
        created.id,
        [
          GpsPoint(lat: 22.7759, lng: 73.7092, t: DateTime(2026, 10, 20, 9, 6)),
        ],
      );
      expect(repo.trips[created.id]!.gpsTrail, hasLength(3));
      expect(
        repo.trips[created.id]!.gpsTrail.last,
        GpsPoint(lat: 22.7759, lng: 73.7092, t: DateTime(2026, 10, 20, 9, 6)),
      );
    });

    test('appendGpsTrail batches several points in one call', () async {
      final created = await repo.createTrip(trip);
      final points = [
        GpsPoint(lat: 22.7759, lng: 73.7092, t: DateTime(2026, 10, 20, 9, 6)),
        GpsPoint(lat: 22.7761, lng: 73.7094, t: DateTime(2026, 10, 20, 9, 7)),
      ];
      await repo.appendGpsTrail(created.id, points);
      final stored = repo.trips[created.id]!.gpsTrail;
      expect(stored, hasLength(4)); // 2 seeded by tripDocMapOpen + batch of 2
      expect(stored.skip(2).map((point) => point.t), points.map((point) => point.t));
    });

    test('setEndedAt / setMockLocationDetected update the trip doc', () async {
      final created = await repo.createTrip(trip);
      final end = DateTime(2026, 10, 20, 13, 30);
      await repo.setEndedAt(created.id, end);
      await repo.setMockLocationDetected(created.id, detected: true);

      final stored = repo.trips[created.id]!;
      expect(stored.endedAt, end);
      expect(stored.mockLocationDetected, isTrue);
    });

    test('watchTripByVanIdAndDate ignores other vans and other days', () async {
      await repo.createTrip(trip);
      final otherVan = await repo
          .watchTripByVanIdAndDate(vanId: 'van-99', date: DateTime(2026, 10, 20))
          .first;
      expect(otherVan, isNull);
      final otherDay = await repo
          .watchTripByVanIdAndDate(vanId: 'van-01', date: DateTime(2026, 10, 21))
          .first;
      expect(otherDay, isNull);
    });
  });

  group('FakeNoticesRepository', () {
    Notice notice(String id, String type, String? targetId, DateTime at) =>
        Notice.fromMap({
          ...noticeDocMap(id: id),
          'targetType': type,
          'targetId': targetId,
          'createdAt': Timestamp.fromDate(at),
        });

    test(
        'watchNotices keeps all + van-mine + ward-mine, drops the rest, newest first',
        () async {
      final repo = FakeNoticesRepository([
        notice('n-all', 'all', null, DateTime(2026, 10, 21, 6, 0)),
        notice('n-van-mine', 'van', 'van-01', DateTime(2026, 10, 21, 6, 45)),
        notice('n-van-other', 'van', 'van-02', DateTime(2026, 10, 21, 6, 40)),
        notice('n-ward-mine', 'ward', 'ward-01', DateTime(2026, 10, 21, 7, 0)),
        notice('n-ward-other', 'ward', 'ward-42', DateTime(2026, 10, 21, 7, 5)),
      ]);
      expect(repo, isA<NoticesRepository>());

      final inbox = await repo.watchNotices(
        vanId: 'van-01',
        wardIds: const ['ward-01', 'ward-02', 'ward-03'],
      ).first;
      expect(inbox.map((element) => element.id), const [
        'n-ward-mine',
        'n-van-mine',
        'n-all',
      ]);
    });
  });

  group('FakeComplaintsRepository', () {
    Complaint complaintWithVariations(
      String id, {
      String? category,
      String? wardId,
      String? status,
      DateTime? createdAt,
    }) {
      final map = <String, Object?>{...complaintDocMap(id: id)};
      if (category != null) map['category'] = category;
      if (wardId != null) map['wardId'] = wardId;
      if (status != null) map['status'] = status;
      if (createdAt != null) map['createdAt'] = Timestamp.fromDate(createdAt);
      return Complaint.fromMap(map);
    }

    late FakeComplaintsRepository repo;
    late Complaint pending1;
    late Complaint pending2;

    setUp(() {
      pending1 = complaintWithVariations(
        'complaint-01',
        createdAt: DateTime(2026, 10, 20, 7, 5, 0, 500),
      );
      pending2 = complaintWithVariations(
        'complaint-02',
        wardId: 'ward-02',
        createdAt: DateTime(2026, 10, 20, 8, 0),
      );
      // Distractors: wrong category, wrong ward, wrong day, other status.
      repo = FakeComplaintsRepository([
        pending1,
        pending2,
        complaintWithVariations('c-garbage', category: 'garbage_dump'),
        complaintWithVariations('c-ward', wardId: 'ward-77'),
        complaintWithVariations(
          'c-old',
          createdAt: DateTime(2026, 10, 19, 12, 0),
        ),
        complaintWithVariations('c-status', wardId: 'ward-01', status: 'resolved'),
      ]);
    });

    test(
        'watchMissedCollectionComplaints filters category, wards, day and statuses',
        () async {
      expect(repo, isA<ComplaintsRepository>());
      final pending = await repo
          .watchMissedCollectionComplaints(
            wardIds: const ['ward-01', 'ward-02'],
            day: DateTime(2026, 10, 20),
            statuses: const [ComplaintStatus.received, ComplaintStatus.assigned],
          )
          .first;
      expect(pending.map((element) => element.id), containsAll([pending1.id, pending2.id]));
      expect(pending.map((element) => element.id), isNot(contains('c-garbage')));
      expect(pending.map((element) => element.id), isNot(contains('c-ward')));
      expect(pending.map((element) => element.id), isNot(contains('c-old')));
      expect(pending.map((element) => element.id), isNot(contains('c-status')));
    });

    test('updateStatus(assigned) then updateStatus(resolved, resolvedAt)',
        () async {
      await repo.updateStatus(pending2.id, ComplaintStatus.assigned);
      expect(repo.complaints[pending2.id]!.status, ComplaintStatus.assigned);

      final resolvedAt = DateTime(2026, 10, 20, 11, 0);
      await repo.updateStatus(
        pending2.id,
        ComplaintStatus.resolved,
        resolvedAt: resolvedAt,
      );
      final stored = repo.complaints[pending2.id]!;
      expect(stored.status, ComplaintStatus.resolved);
      expect(stored.resolvedAt, resolvedAt);
      // Ward data untouched by the driver write (0.8 scope).
      expect(stored.wardId, 'ward-02');
      expect(stored.deviceId, 'device-123');
    });

    test('a resolved complaint leaves the received/assigned stream', () async {
      final pending = await repo
          .watchMissedCollectionComplaints(
            wardIds: const ['ward-01'],
            day: DateTime(2026, 10, 20),
            statuses: const [ComplaintStatus.received],
          )
          .first;
      expect(pending.map((element) => element.id), [pending1.id]);
    });
  });

  group('FakeWardsRepository', () {
    late FakeWardsRepository repo;

    setUp(() {
      repo = FakeWardsRepository([
        Ward.fromMap(wardDocMap()),
        Ward.fromMap(wardDocMap(id: 'ward-02')),
      ]);
    });

    test('readWardsByIds resolves the route ward list (missing ids dropped)',
        () async {
      final wards = await repo.readWardsByIds(['ward-01', 'ward-02', 'ward-99']);
      expect(
        wards.map((ward) => ward.id),
        containsAll(const ['ward-01', 'ward-02']),
      );
      expect(wards, hasLength(2));
    });

    test('watchRouteWards streams wards of the route only', () async {
      final events = <List<Ward>>[];
      final subscription = repo.watchRouteWards('route-01').listen(events.add);
      await pumpEventQueue();
      expect(events, hasLength(1));
      expect(
        events.single.map((ward) => ward.id).toSet(),
        const {'ward-01', 'ward-02'},
      );
      await subscription.cancel();
    });
  });

  group('FakeRoutesRepository', () {
    test('readRoute resolves the visiting order', () async {
      final repo = FakeRoutesRepository([RouteModel.fromMap(routeDocMap())]);
      expect(repo, isA<RoutesRepository>());
      final route = await repo.readRoute('route-01');
      expect(route!.wardIds, const ['ward-01', 'ward-02', 'ward-03']);
      expect(route.name, 'Godhra Fort Route');
      expect(route.scheduledStartTime, '07:30');
      expect(await repo.readRoute('route-404'), isNull);
    });
  });
}
