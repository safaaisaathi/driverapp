import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

/// Sample doc maps mirroring PRD-2 0.2 shapes exactly (field names, enum
/// snake_case strings, `{lat,lng}` locations, Ticket ID format from 0.11).
///
/// Used by the model round-trip tests and the fake-seeded repository tests.


final DateTime _ward1DoneAt = DateTime(2026, 10, 20, 8, 15, 3, 750);
final DateTime _ward2DoneAt = DateTime(2026, 10, 20, 8, 41, 9, 120);
final DateTime _gps1At = DateTime(2026, 10, 20, 8, 15, 11, 5, 250);
final DateTime _gps2At = DateTime(2026, 10, 20, 8, 15, 41, 6, 500);
final DateTime _tripDate = DateTime(2026, 10, 20);
final DateTime _tripStartedAt = DateTime(2026, 10, 20, 7, 30, 11, 123, 456);
final DateTime _tripEndedAt = DateTime(2026, 10, 20, 13, 25, 55, 999);
final DateTime _vanUpdatedAt = DateTime(2026, 10, 20, 8, 15, 11, 0);
final DateTime _complaintCreatedAt = DateTime(2026, 10, 20, 7, 5, 0, 500);
final DateTime _complaintResolvedAt = DateTime(2026, 10, 20, 10, 22, 1, 999);
final DateTime _noticeCreatedAt = DateTime(2026, 10, 21, 6, 45);

int ms(DateTime value) => value.millisecondsSinceEpoch;

String iso(DateTime value) => value.toIso8601String();

Timestamp ts(DateTime value) => Timestamp.fromDate(value);

Map<String, Object?> wardDocMap({String id = 'ward-01'}) => {
      'id': id,
      'name': 'Godhra Ward 1',
      'nameGu': 'ગોધરા વોર્ડ 1',
      'code': 'GRD-01',
      'type': 'urban',
      'center': {'lat': 22.7759, 'lng': 73.7092},
      'radiusM': 500,
      'routeId': 'route-01',
      'inspectorId': 'staff-01',
      'escalationTo': 'staff-09',
    };

Map<String, Object?> routeDocMap({String id = 'route-01'}) => {
      'id': id,
      'name': 'Godhra Fort Route',
      'wardIds': <String>['ward-01', 'ward-02', 'ward-03'],
      'scheduledStartTime': '07:30',
    };

Map<String, Object?> vanDocMap({String id = 'van-01'}) => {
      'id': id,
      'plateNo': 'GJ-05-AB-1234',
      'routeId': 'route-01',
      'status': 'on_shift',
      'lastLocation': {
        'lat': 22.7759,
        'lng': 73.7092,
        'updatedAt': ts(_vanUpdatedAt),
        'speedKmph': 12.5,
      },
      'currentTripId': 'trip-01',
      'batteryPct': 76,
    };

/// Closed-shift shape: `endedAt` is filled (End Shift was tapped).
Map<String, Object?> tripDocMap({String id = 'trip-01'}) => {
      'id': id,
      'vanId': 'van-01',
      'routeId': 'route-01',
      'date': ts(_tripDate),
      'startedAt': ts(_tripStartedAt),
      'endedAt': ts(_tripEndedAt),
      'wardsDone': <Object?>[
        {
          'wardId': 'ward-01',
          'doneAt': ts(_ward1DoneAt),
          'flagged': false,
        },
        {
          'wardId': 'ward-02',
          'doneAt': ts(_ward2DoneAt),
          'flagged': true,
        },
      ],
      'alertedWardIds': <String>['ward-01'],
      'gpsTrail': <Object?>[
        {'lat': 22.7759, 'lng': 73.7092, 't': ts(_gps1At)},
        {'lat': 22.7766, 'lng': 73.7099, 't': ts(_gps2At)},
      ],
      'mockLocationDetected': false,
    };

/// Working-shift shape: `endedAt` is null (End Shift not yet tapped).
Map<String, Object?> tripDocMapOpen({String id = 'trip-01'}) => {
      ...tripDocMap(id: id),
      'endedAt': null,
    };

Map<String, Object?> noticeDocMap({String id = 'notice-01'}) => {
      'id': id,
      'targetType': 'van',
      'targetId': 'van-01',
      'message': 'Route change today: skip ward-02, add ward-04.',
      'createdAt': ts(_noticeCreatedAt),
      'createdBy': 'staff-01',
    };

Map<String, Object?> complaintDocMap({String id = 'complaint-01'}) => {
      'id': id,
      'ticketId': 'PMH-20261020-0001',
      'deviceId': 'device-123',
      'category': 'missed_collection',
      'photoUrl': 'complaints/complaint-01/photo.jpg',
      'location': {'lat': 22.7751, 'lng': 73.7088},
      'wardId': 'ward-01',
      'createdAt': ts(_complaintCreatedAt),
      'status': 'received',
      'assignedTo': null,
      'escalationLevel': 0,
      'resolvedPhotoUrl': null,
      'resolvedAt': null,
      'mergedInto': null,
      'note': '',
    };

/// The same trip doc with every timestamp as epoch millis (`int`).
Map<String, Object?> tripDocMapMillis() => {
      ...tripDocMap(),
      'date': ms(_tripDate),
      'startedAt': ms(_tripStartedAt),
      'endedAt': ms(_tripEndedAt),
      'wardsDone': [
        {
          'wardId': 'ward-01',
          'doneAt': ms(_ward1DoneAt),
          'flagged': false,
        },
        {
          'wardId': 'ward-02',
          'doneAt': ms(_ward2DoneAt),
          'flagged': true,
        },
      ],
      'gpsTrail': [
        {'lat': 22.7759, 'lng': 73.7092, 't': ms(_gps1At)},
        {'lat': 22.7766, 'lng': 73.7099, 't': ms(_gps2At)},
      ],
    };

/// The same trip doc with every timestamp as an ISO-8601 string.
Map<String, Object?> tripDocMapIso() => {
      ...tripDocMap(),
      'date': iso(_tripDate),
      'startedAt': iso(_tripStartedAt),
      'endedAt': iso(_tripEndedAt),
      'wardsDone': [
        {
          'wardId': 'ward-01',
          'doneAt': iso(_ward1DoneAt),
          'flagged': false,
        },
        {
          'wardId': 'ward-02',
          'doneAt': iso(_ward2DoneAt),
          'flagged': true,
        },
      ],
      'gpsTrail': [
        {'lat': 22.7759, 'lng': 73.7092, 't': iso(_gps1At)},
        {'lat': 22.7766, 'lng': 73.7099, 't': iso(_gps2At)},
      ],
    };

/// The same van doc with `lastLocation.updatedAt` as epoch millis.
Map<String, Object?> vanDocMapMillis() => {
      ...vanDocMap(),
      'lastLocation': {
        'lat': 22.7759,
        'lng': 73.7092,
        'updatedAt': ms(_vanUpdatedAt),
        'speedKmph': 12.5,
      },
    };

/// The same van doc with `lastLocation.updatedAt` as an ISO-8601 string.
Map<String, Object?> vanDocMapIso() => {
      ...vanDocMap(),
      'lastLocation': {
        'lat': 22.7759,
        'lng': 73.7092,
        'updatedAt': iso(_vanUpdatedAt),
        'speedKmph': 12.5,
      },
    };

Map<String, Object?> noticeDocMapMillis() => {
      ...noticeDocMap(),
      'createdAt': ms(_noticeCreatedAt),
    };

Map<String, Object?> complaintDocMapMillis() => {
      ...complaintDocMap(),
      'createdAt': ms(_complaintCreatedAt),
      'resolvedAt': null,
    };

Map<String, Object?> complaintDocMapIsoWithResolvedAt() => {
      ...complaintDocMap(),
      'createdAt': iso(_complaintCreatedAt),
      'status': 'resolved',
      'assignedTo': 'staff-01',
      'escalationLevel': 1,
      'resolvedPhotoUrl': 'complaints/complaint-01/resolved.jpg',
      'resolvedAt': iso(_complaintResolvedAt),
      'note': 'Collected on revisit.',
    };
