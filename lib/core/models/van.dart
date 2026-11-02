import 'package:driverapp/core/domain/geo_point.dart';

import 'firestore_time.dart';

/// `van.status` (0.3). Contract strings only: idle | on_shift | offline.
enum VanStatus {
  idle('idle'),
  onShift('on_shift'),
  offline('offline');

  const VanStatus(this.value);

  /// The exact contract string (0.3).
  final String value;

  /// Parses the contract string; throws on anything else.
  static VanStatus parse(Object? raw, {String field = 'vans.status'}) {
    if (raw is String) {
      for (final value in values) {
        if (value.value == raw) return value;
      }
    }
    throw FormatException('Unknown $field value: $raw');
  }
}

/// The `vans.lastLocation` sub-shape (0.2, 0.13):
/// `{ lat, lng, updatedAt (server timestamp), speedKmph }`. One small map,
/// overwritten on every location write (Flow A step 3).
class VanLastLocation {
  final double lat;

  final double lng;

  final double speedKmph;

  final DateTime? updatedAt;

  const VanLastLocation({
    required this.lat,
    required this.lng,
    required this.speedKmph,
    required this.updatedAt,
  });

  factory VanLastLocation.fromMap(Map<String, Object?> map) {
    final lat = map['lat'];
    final lng = map['lng'];
    final speedKmph = map['speedKmph'];
    if (lat is! num || lng is! num || speedKmph is! num) {
      throw const FormatException(
        'vans.lastLocation does not match {lat,lng,updatedAt,speedKmph} (0.2)',
      );
    }
    return VanLastLocation(
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      speedKmph: speedKmph.toDouble(),
      updatedAt: docTimeToDateTime(map['updatedAt']),
    );
  }

  Map<String, Object?> toMap() => {
        'lat': lat,
        'lng': lng,
        'updatedAt': dateTimeToDocTime(updatedAt),
        'speedKmph': speedKmph,
      };

  @override
  bool operator ==(Object other) =>
      other is VanLastLocation &&
      other.runtimeType == runtimeType &&
      other.lat == lat &&
      other.lng == lng &&
      other.speedKmph == speedKmph &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(runtimeType, lat, lng, speedKmph, updatedAt);

  @override
  String toString() => 'VanLastLocation(${toMap()})';
}

/// The `vans` collection (0.2):
/// id, plateNo, routeId, status, lastLocation{lat,lng,updatedAt,speedKmph},
/// currentTripId, batteryPct.
class Van {
  final String id;

  final String plateNo;

  final String routeId;

  final VanStatus status;

  final VanLastLocation? lastLocation;

  /// Set while the van is on shift, resume seams read it (grilled decision:
  /// resume, never duplicate trips).
  final String? currentTripId;

  final int? batteryPct;

  /// `vans.depot` (0.2 addition, ruling #29): the admin-set depot centre
  /// `{lat, lng}`. Drivers never write it. `null` = no depot, so the
  /// auto-end rule cannot fire.
  final GeoPoint? depot;

  const Van({
    required this.id,
    required this.plateNo,
    required this.routeId,
    required this.status,
    required this.lastLocation,
    required this.currentTripId,
    required this.batteryPct,
    this.depot,
  });

  factory Van.fromMap(Map<String, Object?> map) {
    final lastLocationRaw = map['lastLocation'];
    return Van(
      id: map['id'] as String,
      plateNo: map['plateNo'] as String,
      routeId: map['routeId'] as String,
      status: VanStatus.parse(map['status']),
      lastLocation: lastLocationRaw == null
          ? null
          : VanLastLocation.fromMap(
              Map<String, Object?>.from(lastLocationRaw as Map<Object?, Object?>),
            ),
      currentTripId: map['currentTripId'] as String?,
      batteryPct: (map['batteryPct'] as num?)?.toInt(),
      depot: _parseDepot(map['depot']),
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'plateNo': plateNo,
        'routeId': routeId,
        'status': status.value,
        'lastLocation': lastLocation?.toMap(),
        'currentTripId': currentTripId,
        'batteryPct': batteryPct,
        // Omitted when null: a full-doc round trip must never erase an
        // admin-set depot.
        if (depot != null) 'depot': {'lat': depot!.lat, 'lng': depot!.lng},
      };

  @override
  bool operator ==(Object other) =>
      other is Van &&
      other.runtimeType == runtimeType &&
      other.id == id &&
      other.plateNo == plateNo &&
      other.routeId == routeId &&
      other.status == status &&
      other.lastLocation == lastLocation &&
      other.currentTripId == currentTripId &&
      other.batteryPct == batteryPct &&
      other.depot == depot;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        id,
        plateNo,
        routeId,
        status,
        lastLocation,
        currentTripId,
        batteryPct,
        depot,
      );

  @override
  String toString() => 'Van(${toMap()})';
}

/// Parses `vans.depot` = `{lat, lng}`; throws on a shape mismatch so a bad
/// admin edit surfaces instead of silently disabling auto-end.
GeoPoint? _parseDepot(Object? raw) {
  if (raw == null) return null;
  final map = Map<String, Object?>.from(raw as Map<Object?, Object?>);
  final lat = map['lat'];
  final lng = map['lng'];
  if (lat is! num || lng is! num) {
    throw const FormatException('vans.depot does not match {lat,lng} (0.2)');
  }
  return (lat: lat.toDouble(), lng: lng.toDouble());
}
