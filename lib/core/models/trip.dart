import 'firestore_time.dart';

/// One Mark Ward Done entry (0.2): `{wardId, doneAt, flagged}`.

class WardDone {
  final String wardId;

  final DateTime doneAt;

  final bool flagged;

  const WardDone({
    required this.wardId,
    required this.doneAt,
    required this.flagged,
  });

  factory WardDone.fromMap(Map<String, Object?> map) => WardDone(
        wardId: map['wardId'] as String,
        doneAt: docTimeToDateTimeRequired(map['doneAt'], 'trips.wardsDone.doneAt'),
        flagged: (map['flagged'] ?? false) as bool,
      );

  Map<String, Object?> toMap() => {
        'wardId': wardId,
        'doneAt': dateTimeToDocTime(doneAt),
        'flagged': flagged,
      };

  @override
  bool operator ==(Object other) =>
      other is WardDone &&
      other.runtimeType == runtimeType &&
      other.wardId == wardId &&
      other.doneAt == doneAt &&
      other.flagged == flagged;

  @override
  int get hashCode => Object.hash(runtimeType, wardId, doneAt, flagged);

  @override
  String toString() => 'WardDone(${toMap()})';
}

/// One Trail point (0.2): `{lat, lng, t}`. Field names are contractual.
class GpsPoint {
  final double lat;

  final double lng;

  final DateTime t;

  const GpsPoint({required this.lat, required this.lng, required this.t});

  factory GpsPoint.fromMap(Map<String, Object?> map) {
    final lat = map['lat'];
    final lng = map['lng'];
    if (lat is! num || lng is! num) {
      throw const FormatException(
        'trips.gpsTrail point does not match {lat,lng,t} shape (0.2)',
      );
    }
    return GpsPoint(
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      t: docTimeToDateTimeRequired(map['t'], 'trips.gpsTrail.t'),
    );
  }

  Map<String, Object?> toMap() => {
        'lat': lat,
        'lng': lng,
        't': dateTimeToDocTime(t),
      };

  @override
  bool operator ==(Object other) =>
      other is GpsPoint &&
      other.runtimeType == runtimeType &&
      other.lat == lat &&
      other.lng == lng &&
      other.t == t;

  @override
  int get hashCode => Object.hash(runtimeType, lat, lng, t);

  @override
  String toString() => 'GpsPoint(${toMap()})';
}

/// The `trips` collection (0.2): id, vanId, routeId, date, startedAt, endedAt,
/// wardsDone[{wardId,doneAt,flagged}], alertedWardIds[], gpsTrail[{lat,lng,t}],
/// mockLocationDetected.
class Trip {
  final String id;

  final String vanId;

  final String routeId;

  /// The collection-day calendar date (0.13 "Today": resolved in Asia/Kolkata;
  /// only the driver app writes trips, so this holds the shift's date).
  final DateTime date;

  final DateTime startedAt;

  final DateTime? endedAt;

  final List<WardDone> wardsDone;

  final List<String> alertedWardIds;

  final List<GpsPoint> gpsTrail;

  final bool mockLocationDetected;

  const Trip({
    required this.id,
    required this.vanId,
    required this.routeId,
    required this.date,
    required this.startedAt,
    required this.endedAt,
    required this.wardsDone,
    required this.alertedWardIds,
    required this.gpsTrail,
    required this.mockLocationDetected,
  });

  factory Trip.fromMap(Map<String, Object?> map) {
    final wardsDoneRaw = map['wardsDone'] as List<Object?>?;
    final gpsTrailRaw = map['gpsTrail'] as List<Object?>?;
    final alertedRaw = map['alertedWardIds'] as List<Object?>?;
    return Trip(
      id: map['id'] as String,
      vanId: map['vanId'] as String,
      routeId: map['routeId'] as String,
      date: docTimeToDateTimeRequired(map['date'], 'trips.date'),
      startedAt: docTimeToDateTimeRequired(map['startedAt'], 'trips.startedAt'),
      endedAt: docTimeToDateTime(map['endedAt']),
      wardsDone: wardsDoneRaw == null
          ? const <WardDone>[]
          : wardsDoneRaw
              .map(
                (element) => WardDone.fromMap(
                  Map<String, Object?>.from(element as Map<Object?, Object?>),
                ),
              )
              .toList(),
      alertedWardIds:
          alertedRaw?.map((element) => element as String).toList() ??
              const <String>[],
      gpsTrail: gpsTrailRaw == null
          ? const <GpsPoint>[]
          : gpsTrailRaw
              .map(
                (element) => GpsPoint.fromMap(
                  Map<String, Object?>.from(element as Map<Object?, Object?>),
                ),
              )
              .toList(),
      mockLocationDetected: (map['mockLocationDetected'] ?? false) as bool,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'vanId': vanId,
        'routeId': routeId,
        'date': dateTimeToDocTime(date),
        'startedAt': dateTimeToDocTime(startedAt),
        'endedAt': endedAt == null ? null : dateTimeToDocTime(endedAt),
        'wardsDone': wardsDone.map((wardDone) => wardDone.toMap()).toList(),
        'alertedWardIds': alertedWardIds,
        'gpsTrail': gpsTrail.map((point) => point.toMap()).toList(),
        'mockLocationDetected': mockLocationDetected,
      };

  @override
  bool operator ==(Object other) =>
      other is Trip &&
      other.runtimeType == runtimeType &&
      other.id == id &&
      other.vanId == vanId &&
      other.routeId == routeId &&
      other.date == date &&
      other.startedAt == startedAt &&
      other.endedAt == endedAt &&
      _listEquals(other.wardsDone, wardsDone) &&
      _listEquals(other.alertedWardIds, alertedWardIds) &&
      _listEquals(other.gpsTrail, gpsTrail) &&
      other.mockLocationDetected == mockLocationDetected;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        id,
        vanId,
        routeId,
        date,
        startedAt,
        endedAt,
        wardsDone,
        alertedWardIds,
        gpsTrail,
        mockLocationDetected,
      );

  @override
  String toString() => 'Trip(${toMap()})';
}

/// Content-wise list equality for the trip arrays in `==` above.
bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}
