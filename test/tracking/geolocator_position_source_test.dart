/// Geolocator → domain fix mapping tests (F-D9 intake):
/// `Position.isMocked` must reach the engine as `VanFix.isMocked`.
///
/// Fake-style: constructing a `geolocator.Position` is plain data (no
/// platform channels, spec seam discipline) — only the MAPPING is real code.
library;

import 'package:driverapp/features/tracking/data/geolocator_position_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  final t = DateTime.utc(2026, 10, 24, 8);

  test('mocked position maps isMocked: true', () {
    final fix = positionToVanFix(
      Position(
        latitude: 22.678,
        longitude: 77.0,
        timestamp: t,
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 3.2,
        speedAccuracy: 0,
        isMocked: true,
      ),
    );
    expect(fix.isMocked, isTrue);
    expect(fix.speedKmph, closeTo(3.2 * 3.6, 1e-9));
  });

  test('real position maps isMocked: false', () {
    final fix = positionToVanFix(
      Position(
        latitude: 22.678,
        longitude: 77.0,
        timestamp: t,
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: -1,
        speedAccuracy: 0,
        isMocked: false,
      ),
    );
    expect(fix.isMocked, isFalse);
    // Android reports -1 m/s for "speed unavailable" → clamped to 0.
    expect(fix.speedKmph, 0);
  });
}
