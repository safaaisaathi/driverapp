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
abstract class TrailBuffer {
  /// How many points are currently buffered and unflushed.
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
