/// Real geolocator-backed position source (F-D2 step 3).
///
/// The tracking feature's only file that calls geolocator for fixes; the
/// engine tests inject fakes instead (spec seam discipline). Sending the
/// `distanceFilter = minMoveM` with every stream is how the PRD's F-D2
/// step 3 is wired.
library;

import 'package:geolocator/geolocator.dart';

import '../domain/position_fix.dart';
import '../domain/position_source.dart';

class GeolocatorPositionSource implements PositionSource {
  const GeolocatorPositionSource();

  @override
  Stream<VanFix> fixes({required int distanceFilterM}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterM,
      ),
    ).map(_toVanFix);
  }
}

/// Maps geolocator's Position onto the domain fix shape. `speedKmph` is
/// m/s * 3.6, clamped to >= 0 (Android reports -1 when speed is unknown).
VanFix positionToVanFix(Position position) => VanFix(
      lat: position.latitude,
      lng: position.longitude,
      speedKmph: _clampSpeedKmph(position.speed),
      t: position.timestamp,
    );

VanFix _toVanFix(Position position) => positionToVanFix(position);

double _clampSpeedKmph(double speedMs) {
  if (speedMs.isNegative) return 0;
  return speedMs * 3.6;
}
