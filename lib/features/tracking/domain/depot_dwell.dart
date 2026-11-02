/// Depot dwell rule (PRD-2 §0.16 ruling #29).
///
/// The shift auto-ends when the van stays inside [radiusM] metres of
/// `vans.depot` for [limit] continuously. Two things reset the clock:
/// leaving the radius, and moving more than [resetMoveM] metres from the
/// dwell anchor (a van shuffling around the yard is not "parked").
///
/// Pure and clock-injected: the engine feeds it every fix, the tests feed
/// it synthetic positions and times. It fires at most once per run.
library;

import 'package:driverapp/core/config/constants.dart';
import 'package:driverapp/core/domain/geo.dart';
import 'package:driverapp/core/domain/geo_point.dart';

class DepotDwellTracker {
  DepotDwellTracker({
    required this.depot,
    this.radiusM = depotRadiusM,
    this.limit = const Duration(hours: depotDwellLimitHours),
    this.resetMoveM = depotDwellResetM,
  });

  /// Admin-set depot centre (`vans.depot`).
  final GeoPoint depot;

  /// Coverage radius around [depot].
  final double radiusM;

  /// Continuous stay that triggers the auto-end.
  final Duration limit;

  /// Movement from the dwell anchor that restarts the clock.
  final double resetMoveM;

  GeoPoint? _anchor;
  DateTime? _insideSince;
  bool _fired = false;

  /// Start of the current continuous stay, `null` while outside the depot.
  DateTime? get insideSince => _insideSince;

  /// Whether this run already reported the auto-end (single latch).
  bool get fired => _fired;

  /// Feeds one position at [at]. Returns `true` exactly once per tracker,
  /// when the continuous stay first reaches [limit].
  bool update(GeoPoint position, DateTime at) {
    if (_fired) return false;

    if (haversineDistanceM(position, depot) > radiusM) {
      _anchor = null;
      _insideSince = null;
      return false;
    }

    final anchor = _anchor;
    final since = _insideSince;
    if (anchor == null || since == null) {
      _anchor = position;
      _insideSince = at;
      return false;
    }

    if (haversineDistanceM(position, anchor) > resetMoveM) {
      _anchor = position;
      _insideSince = at;
      return false;
    }

    if (at.difference(since) >= limit) {
      _fired = true;
      return true;
    }
    return false;
  }
}
