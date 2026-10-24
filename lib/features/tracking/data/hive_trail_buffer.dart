/// Hive-backed Trail buffer: one box `trail-<tripId>` per trip, with ALL
/// pending points stored as ONE ordered list under a single key. That
/// layout makes the two order guarantees trivial:
/// - flush order = buffer order (take from the front),
/// - catch-up order (a failed batch is re-inserted at the FRONT, never
///   appended after newer points).
library;

import 'package:hive/hive.dart';
import 'package:driverapp/core/models/models.dart';

import '../domain/trail_buffer.dart';

/// Box name convention for the local Trail buffer (ticket 05 deliverable).
String trailBoxName(String tripId) => 'trail-$tripId';

/// All pending points of a trip live under this single ordered key.
const String trailBoxEntryKey = 'trail';

typedef _StoredPoint = Map<String, Object?>;

class HiveTrailBuffer implements TrailBuffer {
  HiveTrailBuffer(this._box);

  final Box _box;

  static Future<TrailBuffer> open(String tripId) async {
    final box = await Hive.openBox<_StoredPoint>(trailBoxName(tripId));
    return HiveTrailBuffer(box);
  }

  /// Reads the stored ordered list. `Map` entries from Hive come back as
  /// `Map<String/Object?>` with dynamic typing — normalize defensively.
  List<_StoredPoint> _read() {
    final raw = _box.get(trailBoxEntryKey);
    // Growable: add()/putBackOldest() mutate the result — a const list made
    // a FRESH box throw on its first add (silent zero-trail bug, F-D7).
    if (raw is! List) return <_StoredPoint>[];
    return raw
        .whereType<Map>()
        .map((map) => Map<String, Object?>.from(map as Map<Object?, Object?>))
        .toList();
  }

  Future<void> _write(List<_StoredPoint> points) =>
      _box.put(trailBoxEntryKey, points);

  @override
  int get pendingCount => _read().length;

  @override
  Future<void> add(GpsPoint point) async {
    final list = _read()..add(point.toMap());
    await _write(list);
  }

  @override
  Future<List<GpsPoint>> takeOldest({int? limit}) async {
    final list = _read();

    final count =
        limit == null || limit >= list.length ? list.length : limit;
    if (count == 0) return const <GpsPoint>[];

    final taken = list
        .sublist(0, count)
        .map(GpsPoint.fromMap)
        .toList();
    await _write(list.sublist(count));
    return taken;
  }

  @override
  Future<void> putBackOldest(List<GpsPoint> points) async {
    if (points.isEmpty) return;
    final list = _read()
      ..insertAll(0, points.map((point) => point.toMap()));
    await _write(list);
  }
}
