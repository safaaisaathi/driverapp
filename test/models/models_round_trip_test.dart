import 'package:driverapp/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sample_maps.dart';

void main() {
  group('round-trip: fromMap ∘ toMap on 0.2 doc shapes', () {
    test('wards', () {
      final model = Ward.fromMap(wardDocMap());
      final roundTrip = Ward.fromMap(model.toMap());
      expect(roundTrip, model);
      expect(model.toMap(), roundTrip.toMap());
      expect(model.type, WardType.urban);
      expect(model.center, const LocationPoint(lat: 22.7759, lng: 73.7092));
      expect(model.radiusM, 500.0); // parsed from an int in the doc map
    });

    test('routes', () {
      final model = RouteModel.fromMap(routeDocMap());
      final roundTrip = RouteModel.fromMap(model.toMap());
      expect(roundTrip, model);
      expect(model.wardIds, const ['ward-01', 'ward-02', 'ward-03']);
      expect(model.scheduledStartTime, '07:30');
    });

    test('vans (Timestamp updatedAt)', () {
      final model = Van.fromMap(vanDocMap());
      final roundTrip = Van.fromMap(model.toMap());
      expect(roundTrip, model);
      expect(model.status, VanStatus.onShift);
      expect(model.lastLocation!.updatedAt, _vanUpdatedAt);
      expect(model.lastLocation!.speedKmph, 12.5);
      expect(model.currentTripId, 'trip-01');
      expect(model.batteryPct, 76);
    });

    test('vans (updatedAt as epoch millis and as ISO string)', () {
      final fromMillis = Van.fromMap(vanDocMapMillis());
      final fromIso = Van.fromMap(vanDocMapIso());
      expect(fromMillis, Van.fromMap(vanDocMap()));
      expect(fromIso, Van.fromMap(vanDocMap()));
    });

    test('vans: empty lastLocation shape (van never reported)', () {
      final map = vanDocMap()..remove('lastLocation');
      final model = Van.fromMap(<String, Object?>{
        ...map,
        'lastLocation': null,
        'batteryPct': null,
        'currentTripId': null,
      });
      final roundTrip = Van.fromMap(model.toMap());
      expect(roundTrip, model);
      expect(model.lastLocation, isNull);
      expect(model.batteryPct, isNull);
    });

    test('vans: admin depot tag (ruling #29) parses and round-trips', () {
      final model = Van.fromMap(<String, Object?>{
        ...vanDocMap(),
        'depot': {'lat': 22.678, 'lng': 77.0},
      });
      expect(model.depot, (lat: 22.678, lng: 77.0));
      expect(Van.fromMap(model.toMap()).depot, model.depot);
    });

    test('vans: no depot → null and toMap never writes one', () {
      final model = Van.fromMap(vanDocMap());
      expect(model.depot, isNull);
      expect(model.toMap().containsKey('depot'), isFalse);
    });

    test('vans: malformed depot throws instead of silently disabling', () {
      expect(
        () => Van.fromMap(<String, Object?>{
          ...vanDocMap(),
          'depot': {'lat': 22.678},
        }),
        throwsFormatException,
      );
    });

    test('trips (closed shift, Timestamp encodings)', () {
      final model = Trip.fromMap(tripDocMap());
      final roundTrip = Trip.fromMap(model.toMap());
      expect(roundTrip, model);
      expect(model.date, _tripDate);
      expect(model.startedAt, _tripStartedAt);
      expect(model.endedAt, _tripEndedAt);
      expect(model.wardsDone.length, 2);
      // Visiting order preserved inside wardsDone.
      expect(model.wardsDone.map((entry) => entry.wardId).toList(),
          const ['ward-01', 'ward-02']);
      expect(model.wardsDone[1].flagged, isTrue); // Flagged entries kept
      expect(model.gpsTrail.length, 2);
      expect(model.gpsTrail.last.t, _gps2At);
      expect(model.mockLocationDetected, isFalse);
    });

    test('trips (open shift: endedAt null)', () {
      final model = Trip.fromMap(tripDocMapOpen());
      final roundTrip = Trip.fromMap(model.toMap());
      expect(roundTrip, model);
      expect(model.endedAt, isNull);
    });

    test('trips (timestamps as epoch millis)', () {
      // Millis/ISO encodings are test conveniences the model layer accepts
      // (see firestore_time.dart); they carry less precision than a doc's
      // Timestamp, so assert the round-trip invariant per encoding instead of
      // equality with the microsecond-precision canonical sample.
      final fromMillis = Trip.fromMap(tripDocMapMillis());
      expect(Trip.fromMap(fromMillis.toMap()), fromMillis);

      final fromIso = Trip.fromMap(tripDocMapIso());
      expect(Trip.fromMap(fromIso.toMap()), fromIso);
    });

    test('trips (0.16: driverId + wardIds round-trip)', () {
      final model = Trip.fromMap(<String, Object?>{
        ...tripDocMap(),
        'driverId': 'AB-1234',
        'wardIds': <String>['ward-01', 'ward-02'],
      });
      final roundTrip = Trip.fromMap(model.toMap());
      expect(roundTrip, model);
      expect(model.driverId, 'AB-1234');
      expect(model.wardIds, const ['ward-01', 'ward-02']);
      // toMap always writes both fields (0.16 contract additions).
      expect(model.toMap()['driverId'], 'AB-1234');
      expect(model.toMap()['wardIds'], const ['ward-01', 'ward-02']);
    });

    test('trips tolerant read: old 0.2 doc without driverId/wardIds', () {
      // Old trip docs predate the 0.16 contract and never fail to parse.
      final model = Trip.fromMap(tripDocMap());
      expect(model.driverId, '');
      expect(model.wardIds, isEmpty);
      // toMap still writes both fields so a re-save never drops them.
      final roundTrip = Trip.fromMap(model.toMap());
      expect(roundTrip.driverId, '');
      expect(roundTrip.wardIds, isEmpty);
      expect(model.toMap()['driverId'], '');
      expect(model.toMap()['wardIds'], isEmpty);
    });

    test('trips equality: driverId and wardIds count', () {
      final base = Trip.fromMap(<String, Object?>{
        ...tripDocMap(),
        'driverId': 'AB-1234',
        'wardIds': <String>['ward-01', 'ward-02'],
      });
      final otherDriver = Trip.fromMap(<String, Object?>{
        ...tripDocMap(),
        'driverId': 'CD-5678',
        'wardIds': <String>['ward-01', 'ward-02'],
      });
      final otherWards = Trip.fromMap(<String, Object?>{
        ...tripDocMap(),
        'driverId': 'AB-1234',
        'wardIds': <String>['ward-01'],
      });
      expect(base, isNot(otherDriver));
      expect(base, isNot(otherWards));
      expect(base.hashCode, isNot(otherDriver.hashCode));
    });

    test('drivers (0.16: the driver doc round-trips)', () {
      final model = Driver.fromMap(driverDocMap());
      final roundTrip = Driver.fromMap(model.toMap());
      expect(roundTrip, model);
      expect(model.id, 'AB-1234');
      expect(model.wardIds, const ['ward-01', 'ward-02']);
    });

    test('drivers tolerant read: a doc without wardIds parses as empty', () {
      // A malformed driver doc must never crash the lookup (a missing
      // field is an admin data error, not a fatal TypeError).
      final data = Map<String, Object?>.from(driverDocMap())..remove('wardIds');
      final model = Driver.fromMap(data);
      expect(model.wardIds, isEmpty);
      // toMap still writes the field so a re-save never drops it.
      expect(model.toMap()['wardIds'], isEmpty);
      expect(Driver.fromMap(model.toMap()), model);
    });

    test('notices', () {
      final model = Notice.fromMap(noticeDocMap());
      final roundTrip = Notice.fromMap(model.toMap());
      expect(roundTrip, model);
      expect(model.targetType, NoticeTargetType.van);
      expect(model.targetId, 'van-01');
    });

    test('notices (createdAt as epoch millis)', () {
      expect(
        Notice.fromMap(noticeDocMapMillis()),
        Notice.fromMap(noticeDocMap()),
      );
    });

    test('notices: targetType `all` carries null targetId', () {
      final map = <String, Object?>{...noticeDocMap(), 'targetType': 'all', 'targetId': null};
      final model = Notice.fromMap(map);
      final roundTrip = Notice.fromMap(model.toMap());
      expect(roundTrip, model);
      expect(model.targetType, NoticeTargetType.all);
      expect(model.targetId, isNull);
    });

    test('complaints', () {
      final model = Complaint.fromMap(complaintDocMap());
      final roundTrip = Complaint.fromMap(model.toMap());
      expect(roundTrip, model);
      expect(model.ticketId, 'PMH-20261020-0001'); // 0.11 ticket format
      expect(model.category, ComplaintCategory.missedCollection);
      expect(model.status, ComplaintStatus.received);
      expect(model.escalationLevel, 0);
      expect(model.resolvedAt, isNull);
    });

    test('complaints (resolved shape, ISO timestamps)', () {
      final model = Complaint.fromMap(complaintDocMapIsoWithResolvedAt());
      final roundTrip = Complaint.fromMap(model.toMap());
      expect(roundTrip, model);
      expect(model.status, ComplaintStatus.resolved);
      expect(model.resolvedAt, _complaintResolvedAt);
      expect(model.escalationLevel, 1);
    });

    test('complaints (createdAt as epoch millis)', () {
      expect(
        Complaint.fromMap(complaintDocMapMillis()),
        Complaint.fromMap(complaintDocMap()),
      );
    });
  });

  group('enum contract strings (0.3, exactly)', () {
    test('van.status', () {
      expect(
        VanStatus.values.map((value) => value.value),
        const ['idle', 'on_shift', 'offline'],
      );
      expect(VanStatus.parse('idle'), VanStatus.idle);
      expect(VanStatus.parse('on_shift'), VanStatus.onShift);
      expect(VanStatus.parse('offline'), VanStatus.offline);
      expect(
        () => VanStatus.parse('on-shift'),
        throwsA(isA<FormatException>()),
      );
    });

    test('complaint.category', () {
      expect(
        ComplaintCategory.values.map((value) => value.value),
        const ['garbage_dump', 'open_gutter', 'missed_collection', 'other'],
      );
    });

    test('complaint.status', () {
      expect(
        ComplaintStatus.values.map((value) => value.value),
        const ['received', 'assigned', 'resolved', 'escalated'],
      );
    });

    test('notice.targetType', () {
      expect(
        NoticeTargetType.values.map((value) => value.value),
        const ['van', 'ward', 'all'],
      );
    });

    test('ward.type', () {
      expect(
        WardType.values.map((value) => value.value),
        const ['urban', 'rural'],
      );
      expect(WardType.parse('rural'), WardType.rural);
    });

    test('trip list entries carry no invented enums', () {
      // wardsDone entries are {wardId, doneAt, flagged} — flagged is bool.
      final entry = WardDone.fromMap(<String, Object?>{
        'wardId': 'ward-03',
        'doneAt': '2026-10-20T08:55:00.000',
        'flagged': true,
      });
      expect(entry.flagged, isTrue);
      final roundTrip = WardDone.fromMap(entry.toMap());
      expect(roundTrip, entry);
    });
  });
}

/// Mirrors of the sample timestamps (kept private to this test).
final _vanUpdatedAt = DateTime(2026, 10, 20, 8, 15, 11, 0);
final _tripDate = DateTime(2026, 10, 20);
final _tripStartedAt = DateTime(2026, 10, 20, 7, 30, 11, 123, 456);
final _tripEndedAt = DateTime(2026, 10, 20, 13, 25, 55, 999);
final _gps2At = DateTime(2026, 10, 20, 8, 15, 41, 6, 500);
final _complaintResolvedAt = DateTime(2026, 10, 20, 10, 22, 1, 999);
