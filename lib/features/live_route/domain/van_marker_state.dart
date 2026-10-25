/// Van-marker semantics for the Live Route screen: everything about the van's
/// own position that the map renders — pure, no widgets (0.13 stale rule plus
/// the "Last seen X min ago" wording of contract 0.13 / ruling 6).
library;

import 'package:driverapp/core/config/constants.dart';
import 'package:driverapp/core/domain/geo_point.dart';
import 'package:driverapp/core/domain/ist_clock.dart';
import 'package:driverapp/core/models/models.dart';

/// What the map needs to draw the van marker.
class VanMarkerState {
  final GeoPoint position;

  /// Speed shown to the driver (informational).
  final double speedKmph;

  /// Whether `lastLocation.updatedAt` is older than `staleLocationSec`
  /// (contract 0.4 / 0.13). A null `updatedAt` counts stale: the position's
  /// age is unknown, so it must not be presented as live.
  final bool isStale;

  /// Minutes since `updatedAt`, floored and clamped ≥ 0 (ruling 6) — the
  /// caption for the stale "last seen X min ago" rendering.
  final int minutesSinceUpdate;

  const VanMarkerState({
    required this.position,
    required this.speedKmph,
    required this.isStale,
    required this.minutesSinceUpdate,
  });

  /// Pure builder from the van's `lastLocation` sub-shape and [now] so tests
  /// drive the clock instead of calling `DateTime.now()` here.
  factory VanMarkerState.of(VanLastLocation? location, DateTime now) {
    final at = location?.updatedAt;
    final isStale =
        at == null || now.difference(at) > Duration(seconds: staleLocationSec);
    return VanMarkerState(
      position: (
        lat: location?.lat ?? 0,
        lng: location?.lng ?? 0,
      ),
      speedKmph: location?.speedKmph ?? 0,
      isStale: isStale,
      minutesSinceUpdate: at == null ? 0 : minutesAgoIST(at, now),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VanMarkerState &&
      other.runtimeType == runtimeType &&
      other.position == position &&
      other.speedKmph == speedKmph &&
      other.isStale == isStale &&
      other.minutesSinceUpdate == minutesSinceUpdate;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        position,
        speedKmph,
        isStale,
        minutesSinceUpdate,
      );

  @override
  String toString() =>
      'VanMarkerState($position speed=$speedKmph stale=$isStale '
      'minutes=$minutesSinceUpdate)';
}
