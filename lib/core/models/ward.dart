import 'location.dart';

/// `ward.type` (0.3). Contract strings only.
enum WardType {
  urban('urban'),
  rural('rural');

  const WardType(this.value);

  /// The exact contract string (0.3).
  final String value;

  /// Parses the contract string; throws on anything else.
  static WardType parse(Object? raw, {String field = 'wards.type'}) {
    if (raw is String) {
      for (final value in values) {
        if (value.value == raw) return value;
      }
    }
    throw FormatException('Unknown $field value: $raw');
  }
}

/// The `wards` collection (0.2):
/// id, name, nameGu, code, type, center{lat,lng}, radiusM, routeId,
/// inspectorId, escalationTo (staffId).
class Ward {
  final String id;

  final String name;

  final String nameGu;

  final String code;

  final WardType type;

  final LocationPoint center;

  final double radiusM;

  final String routeId;

  final String inspectorId;

  /// Staff id the complaint escalates to via `wards.escalationTo` (0.3).
  final String escalationTo;

  const Ward({
    required this.id,
    required this.name,
    required this.nameGu,
    required this.code,
    required this.type,
    required this.center,
    required this.radiusM,
    required this.routeId,
    required this.inspectorId,
    required this.escalationTo,
  });

  factory Ward.fromMap(Map<String, Object?> map) => Ward(
        id: map['id'] as String,
        name: map['name'] as String,
        nameGu: map['nameGu'] as String,
        code: map['code'] as String,
        type: WardType.parse(map['type']),
        center: LocationPoint.fromMap(
          Map<String, Object?>.from(map['center'] as Map<Object?, Object?>),
        ),
        radiusM: (map['radiusM'] as num).toDouble(),
        routeId: map['routeId'] as String,
        inspectorId: map['inspectorId'] as String,
        escalationTo: map['escalationTo'] as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'nameGu': nameGu,
        'code': code,
        'type': type.value,
        'center': center.toMap(),
        'radiusM': radiusM,
        'routeId': routeId,
        'inspectorId': inspectorId,
        'escalationTo': escalationTo,
      };

  @override
  bool operator ==(Object other) =>
      other is Ward &&
      other.runtimeType == runtimeType &&
      other.id == id &&
      other.name == name &&
      other.nameGu == nameGu &&
      other.code == code &&
      other.type == type &&
      other.center == center &&
      other.radiusM == radiusM &&
      other.routeId == routeId &&
      other.inspectorId == inspectorId &&
      other.escalationTo == escalationTo;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        id,
        name,
        nameGu,
        code,
        type,
        center,
        radiusM,
        routeId,
        inspectorId,
        escalationTo,
      );

  @override
  String toString() => 'Ward(${toMap()})';
}
