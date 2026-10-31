/// Seam for the local Trail buffer: points written by the engine are held
/// here and appended to `trips.gpsTrail` in one batch every 30 s
/// (PRD-2 0.13 Flow A step 4).
library;

import 'package:driverapp/core/models/models.dart';

/// FIFO Trail points for ONE trip, persisted locally between flushes.
///
/// Order discipline (contract: trail points in order): [takeOldest] returns
/// the oldest points first; [putBackOldest] puts a failed batch back at the
/// FRONT so catch-up data keeps its order relative to later points.
abstract class TrailBuffer {  /// How many points are currently buffered and unflushed.
  int get pendingCount;

  /// Appends one accepted Write Policy point at the back.
  Future<void> add(GpsPoint point);

  /// Removes and returns up to [limit] oldest points in order; `null`
  /// removes all.
  Future<List<GpsPoint>> takeOldest({int? limit});

  /// Puts a failed batch back at the front, order preserved.
  Future<void> putBackOldest(List<GpsPoint> points);
}

/// Creates the buffer for one trip (the Hive implementation opens the box
/// `trail-<tripId>`).
typedef TrailBufferFactory = Future<TrailBuffer> Function(String tripId);

/// Hard cap for the local Trail buffer per trip: beyond this the OLDEST
/// points are dropped (keeps a long dead-zone from growing memory without
/// bound; not a contract constant).
const int maxTrailBufferPoints = 5000;

/// Largest batch one trail write may carry, measured on the device
/// (issue #13, M215F on the field network):
///
/// - 100 points (~5 KB) -> 1.7 s
/// - 1000 points (~53 KB) -> 8.0 s
/// - 2500 points (~133 KB) -> missed a 25 s deadline (landed ~40 s later)
/// - 5000 points (~265 KB) -> stalled the write stream past a minute
///
/// The flush cadence is 30 s, so a batch has to fit well inside it: 1000
/// points leaves ~22 s of margin on the measured network and drains a full
/// buffer in five ticks. The old code flushed EVERYTHING each tick
/// ([takeOldest] with no limit), which is exactly the write that stalled.
const int maxTrailBatchPoints = 1000;
