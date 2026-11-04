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

/// The `drivers` collection (0.16, CHG-0002): doc id = the normalized driver
/// code `AB-1234` (regex `^[A-Z]{2}-[0-9]{4}$`). Fields: name, phoneMasked,
/// vanId, routeId, wardIds (one or more), active. Writes are admin-only; the
/// app only reads.
///
/// `phoneMasked` is MASKED AT THE SOURCE by the admin callable
/// (`98XXXXXX10`). The app never reads a raw phone: that value lives in
/// `staffPhones/{code}`, which only the district office may read. The mask is
/// not re-applied here, because re-masking a masked value would corrupt it.
class Driver {
  final String id;

  final String name;

  final String phoneMasked;

  final String vanId;

  final String routeId;

  /// The driver's allotted wards (0.16 "one or more"); the live route scopes
  /// the map and ward marking to these (spec Implementation Decisions).
  final List<String> wardIds;

  final bool active;

  const Driver({
    required this.id,
    required this.name,
    required this.phoneMasked,
    required this.vanId,
    required this.routeId,
    required this.wardIds,
    required this.active,
  });

  factory Driver.fromMap(Map<String, Object?> map) {
    // Tolerant read: a driver doc without `wardIds` parses as empty instead
    // of throwing — a malformed doc is an admin data error, never a crash
    // in the lookup (same shape as the Trip model's tolerant reads).
    final wardIdsRaw = map['wardIds'] as List<Object?>?;
    return Driver(
      id: map['id'] as String,
      name: map['name'] as String,
      phoneMasked: map['phoneMasked'] as String,
      vanId: map['vanId'] as String,
      routeId: map['routeId'] as String,
      wardIds:
          wardIdsRaw?.map((element) => element as String).toList() ??
              const <String>[],
      active: map['active'] as bool,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phoneMasked': phoneMasked,
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
      other.phoneMasked == phoneMasked &&
      other.vanId == vanId &&
      other.routeId == routeId &&
      _listEquals(other.wardIds, wardIds) &&
      other.active == active;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        id,
        name,
        phoneMasked,
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
