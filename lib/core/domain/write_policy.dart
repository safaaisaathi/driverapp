/// The Write Policy (PRD-2 section 0.13): decide when a GPS sample is worth
/// writing so a moving van shows movement and a stopped van never looks dead.
library;

import 'package:driverapp/core/config/constants.dart';

import 'geo.dart';
import 'geo_point.dart';

/// Why the Write Policy produced its decision.
enum WriteReason {
  /// No last written point exists yet — the first point of the trip always
  /// writes.
  firstWrite,

  /// The candidate moved at least [minMoveM] from the last written point.
  moved,

  /// The van is (nearly) stationary but [heartbeatSec] passed since the last
  /// write — heartbeat write so a stopped van never looks dead.
  heartbeat,

  /// The candidate hardly moved and no heartbeat is due — nothing to write.
  skipped,
}

/// The outcome of applying the Write Policy to one candidate point.
class WriteDecision {
  /// Seconds between location checks in the current battery state
  /// ([gpsIntervalSec] normally, [gpsIntervalLowBatterySec] on low battery).
  /// This is the sampling cadence the engine should schedule next; it does
  /// not gate the write itself.
  final int intervalUsed;

  /// Whether the candidate point should be written (to `vans.lastLocation`
  /// and the buffered trail).
  final bool shouldWrite;

  /// Why this decision was reached (see [WriteReason]).
  final WriteReason reason;

  const WriteDecision({
    required this.intervalUsed,
    required this.shouldWrite,
    required this.reason,
  });

  @override
  String toString() =>
      'WriteDecision(intervalUsed: $intervalUsed, shouldWrite: $shouldWrite, '
      'reason: $reason)';
}

/// Apply the Write Policy (PRD-2 0.13) to one candidate GPS sample.
///
/// Rules, exactly:
/// - Sampling interval is [gpsIntervalSec], or [gpsIntervalLowBatterySec]
///   when the battery is below [lowBatteryPct]. A `null` [batteryPct] is
///   treated as healthy (unknown battery never slows the van down).
/// - Write only if: no [lastWritten] point exists yet; OR the candidate moved
///   at least [minMoveM] from [lastWritten]; OR [heartbeatSec] passed since
///   [lastWriteTime]. Otherwise skip.
/// - Pure and total: every null combination returns a decision; nothing mutates.
WriteDecision decideWrite({
  required GeoPoint candidate,
  required GeoPoint? lastWritten,
  required DateTime? lastWriteTime,
  required int? batteryPct,
  required DateTime now,
}) {
  final isLowBattery = batteryPct != null && batteryPct < lowBatteryPct;
  final interval = isLowBattery ? gpsIntervalLowBatterySec : gpsIntervalSec;

  // No last written point — always write, regardless of lastWriteTime.
  if (lastWritten == null) {
    return WriteDecision(
      intervalUsed: interval,
      shouldWrite: true,
      reason: WriteReason.firstWrite,
    );
  }

  final movedM = haversineDistanceM(candidate, lastWritten);
  if (movedM >= minMoveM) {
    return WriteDecision(
      intervalUsed: interval,
      shouldWrite: true,
      reason: WriteReason.moved,
    );
  }

  final heartbeatElapsed = lastWriteTime != null &&
      now.difference(lastWriteTime) >= const Duration(seconds: heartbeatSec);
  if (heartbeatElapsed) {
    return WriteDecision(
      intervalUsed: interval,
      shouldWrite: true,
      reason: WriteReason.heartbeat,
    );
  }

  return WriteDecision(
    intervalUsed: interval,
    shouldWrite: false,
    reason: WriteReason.skipped,
  );
}
