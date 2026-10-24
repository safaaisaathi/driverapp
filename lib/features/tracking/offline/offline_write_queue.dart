/// Durable local queue for unsent GPS writes (F-D7; PRD-2 sections 0.13
/// offline note + 3 "Offline" rule).
///
/// Two kinds of unsent points live here while the network is dead:
/// - `vans.lastLocation` candidate writes (see [QueuedLastLocation]) — the
///   contract says only the LATEST position matters for the live map
///   (0.13 "Only the latest `lastLocation` matters"), so the queue holds a
///   SINGLE slot: enqueueing a newer candidate never co-exists with an
///   older one, and a failed send of an older candidate is dropped from the
///   queue as soon as a newer candidate has arrived ("never re-send an
///   older lastLocation after a newer one landed").
/// - Trail points continue to live in the per-trip Hive Trail buffer
///   (`lib/features/tracking/data/hive_trail_buffer.dart`), which already
///   puts failed batches back at the FRONT in order; the sync service
///   drains the same buffer through `appendGpsTrail` (single ordered
///   appends, batch shape preserved).
library;

import 'package:hive/hive.dart';

/// The durable write queue's contract (see the library doc above).
abstract class OfflineWriteQueue {
  /// Queues the latest `vans.lastLocation` candidate; any previously
  /// queued (older) candidate is REPLACED — latest only (0.13 note).
  Future<void> enqueueLastLocation({
    required String vanId,
    required double lat,
    required double lng,
    required double speedKmph,
    required DateTime recordedAt,
  });

  /// Removes and returns the queued lastLocation candidate, if any.
  Future<QueuedLastLocation?> takeLastLocation();

  /// Puts a FAILED candidate back, UNLESS a strictly newer candidate was
  /// meanwhile enqueued (then it is dropped: re-sending it later would
  /// overwrite the newer position on the van doc).
  Future<void> putBackLastLocation(QueuedLastLocation item);

  /// `1` when a lastLocation candidate is pending (the slot holds at most
  /// one), else `0` — the lastLocation part of the un-synced-points count.
  Future<int> get pendingLastLocationCount;
}

/// One queued `vans.lastLocation` candidate
/// (shape per 0.13: lat, lng, speedKmph; `updatedAt` stays a server
/// timestamp handled by the repository — never sent as device time).
class QueuedLastLocation {
  const QueuedLastLocation({
    required this.vanId,
    required this.lat,
    required this.lng,
    required this.speedKmph,
    required this.recordedAt,
  });

  final String vanId;

  final double lat;

  final double lng;

  final double speedKmph;

  /// When the fix was taken (device clock; only used for ordering — it is
  /// NOT written to the van doc).
  final DateTime recordedAt;

  factory QueuedLastLocation.fromMap(Map<String, Object?> map) {
    return QueuedLastLocation(
      vanId: map['vanId'] as String,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      speedKmph: (map['speedKmph'] as num).toDouble(),
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        map['recordedAtMs'] as int,
        isUtc: (map['recordedAtIsUtc'] ?? false) as bool,
      ),
    );
  }

  Map<String, Object?> toMap() => {
    'vanId': vanId,
    'lat': lat,
    'lng': lng,
    'speedKmph': speedKmph,
    // Epoch-ms keeps the instant exact; isUtc keeps DateTime equality
    // intact (ordering and a durable identity).
    'recordedAtMs': recordedAt.millisecondsSinceEpoch,
    'recordedAtIsUtc': recordedAt.isUtc,
  };
}

/// Hive box holding the pending `vans.lastLocation` candidate.
const String offlineQueueBoxName = 'offline-write-queue';

/// Key under which the single lastLocation record is stored.
const String offlineQueueLastLocationKey = 'lastLocation';

class HiveOfflineWriteQueue implements OfflineWriteQueue {
  HiveOfflineWriteQueue() : _boxFuture = Hive.openBox(offlineQueueBoxName);

  final Future<Box> _boxFuture;

  Future<QueuedLastLocation?> _read() async {
    final box = await _boxFuture;
    final raw = box.get(offlineQueueLastLocationKey);
    if (raw is! Map) return null;
    return QueuedLastLocation.fromMap(
      Map<String, Object?>.from(raw as Map<Object?, Object?>),
    );
  }

  Future<void> _remove() async {
    final box = await _boxFuture;
    await box.delete(offlineQueueLastLocationKey);
  }

  @override
  Future<void> enqueueLastLocation({
    required String vanId,
    required double lat,
    required double lng,
    required double speedKmph,
    required DateTime recordedAt,
  }) async {
    final box = await _boxFuture;
    // Latest only: overwrite whatever older candidate was queued.
    await box.put(
      offlineQueueLastLocationKey,
      QueuedLastLocation(
        vanId: vanId,
        lat: lat,
        lng: lng,
        speedKmph: speedKmph,
        recordedAt: recordedAt,
      ).toMap(),
    );
  }

  @override
  Future<QueuedLastLocation?> takeLastLocation() async {
    final item = await _read();
    if (item != null) await _remove();
    return item;
  }

  @override
  Future<void> putBackLastLocation(QueuedLastLocation item) async {
    final pending = await _read();
    if (pending != null && pending.recordedAt.isAfter(item.recordedAt)) {
      // A strictly newer candidate is queued: drop the stale failed send
      // ("never re-send an older lastLocation after a newer one").
      return;
    }
    final box = await _boxFuture;
    await box.put(offlineQueueLastLocationKey, item.toMap());
  }

  @override
  Future<int> get pendingLastLocationCount async =>
      (await _read()) == null ? 0 : 1;
}
