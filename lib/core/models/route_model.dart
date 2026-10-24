/// The `routes` collection (0.2): id, name, wardIds[] (in visiting order),
/// scheduledStartTime ("HH:mm").
///
/// Named `RouteModel` because bare `Route` collides with Flutter's
/// `Navigator` Route; the collection name is still contract-exact: `routes`.
library;

class RouteModel {
  final String id;

  final String name;

  /// Ward ids in visiting order (contract wording, 0.2).
  final List<String> wardIds;

  final String scheduledStartTime;

  const RouteModel({
    required this.id,
    required this.name,
    required this.wardIds,
    required this.scheduledStartTime,
  });

  factory RouteModel.fromMap(Map<String, Object?> map) {
    final wardIdsRaw = map['wardIds'] as List<Object?>?;
    return RouteModel(
      id: map['id'] as String,
      name: map['name'] as String,
      wardIds: wardIdsRaw == null
          ? const <String>[]
          : wardIdsRaw.map((element) => element as String).toList(),
      scheduledStartTime: map['scheduledStartTime'] as String,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'wardIds': wardIds,
        'scheduledStartTime': scheduledStartTime,
      };

  @override
  bool operator ==(Object other) =>
      other is RouteModel &&
      other.runtimeType == runtimeType &&
      other.id == id &&
      other.name == name &&
      _listEquals(other.wardIds, wardIds) &&
      other.scheduledStartTime == scheduledStartTime;

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, wardIds, scheduledStartTime);

  @override
  String toString() => 'RouteModel(${toMap()})';
}

/// Content-wise list equality (Dart `==` on lists is identity-based).
bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}
