/// Driver-code normalization (0.16): trim, uppercase, insert the dash when
/// missing — `ab1234` / `AB-1234` / `ab-1234` all become `AB-1234`. Returns
/// null for any shape that does not match `^[A-Z]{2}-[0-9]{4}$` after
/// normalization, so a bad code never reaches Firestore. Single source of
/// truth: the repository normalizes through this helper and later flow
/// tickets import it too.
String? normalizeDriverCode(String raw) {
  final upper = raw.trim().toUpperCase();
  final candidate = upper.contains('-')
      ? upper
      : upper.length >= 2
          ? '${upper.substring(0, 2)}-${upper.substring(2)}'
          : upper;
  return _driverCodePattern.firstMatch(candidate) == null ? null : candidate;
}

final RegExp _driverCodePattern = RegExp(r'^[A-Z]{2}-[0-9]{4}$');

/// Confirm-card display form of the driver's phone (0.16): strips a
/// leading `+91` country code and shows only the first 2 and last 2
/// digits, e.g. `9876543210` → `98XXXXXX10` (the X count mirrors the real
/// length). Anything that keeps fewer than 4 digits after stripping is
/// returned trimmed but unmasked — the office seeds the phone, and a
/// broken value must never throw on screen.
String maskDriverPhone(String phone) {
  final trimmed = phone.trim();
  final withoutCountryCode = trimmed.startsWith('+91')
      ? trimmed.substring(3)
      : trimmed;
  if (withoutCountryCode.length < 4) return trimmed;
  return '${withoutCountryCode.substring(0, 2)}'
      '${'X' * (withoutCountryCode.length - 4)}'
      '${withoutCountryCode.substring(withoutCountryCode.length - 2)}';
}

/// The `drivers` collection (0.16): doc id = the normalized driver code
/// `AB-1234` (regex `^[A-Z]{2}-[0-9]{4}$`). Fields: name, phone, vanId,
/// routeId, wardIds (one or more), active. Writes are admin-only; the app
/// only reads.
class Driver {
  final String id;

  final String name;

  final String phone;

  final String vanId;

  final String routeId;

  /// The driver's allotted wards (0.16 "one or more"); the live route scopes
  /// the map and ward marking to these (spec Implementation Decisions).
  final List<String> wardIds;

  final bool active;

  const Driver({
    required this.id,
    required this.name,
    required this.phone,
    required this.vanId,
    required this.routeId,
    required this.wardIds,
    required this.active,
  });

  factory Driver.fromMap(Map<String, Object?> map) {
    final wardIdsRaw = map['wardIds'] as List<Object?>;
    return Driver(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      vanId: map['vanId'] as String,
      routeId: map['routeId'] as String,
      wardIds: wardIdsRaw.map((element) => element as String).toList(),
      active: map['active'] as bool,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'vanId': vanId,
        'routeId': routeId,
        'wardIds': wardIds,
        'active': active,
      };

  @override
  bool operator ==(Object other) =>
      other is Driver &&
      other.runtimeType == runtimeType &&
      other.id == id &&
      other.name == name &&
      other.phone == phone &&
      other.vanId == vanId &&
      other.routeId == routeId &&
      _listEquals(other.wardIds, wardIds) &&
      other.active == active;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        id,
        name,
        phone,
        vanId,
        routeId,
        wardIds,
        active,
      );

  @override
  String toString() => 'Driver(${toMap()})';
}

/// Content-wise list equality for `wardIds` in `==` above.
bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}
