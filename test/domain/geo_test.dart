import 'package:driverapp/core/domain/geo.dart';
import 'package:driverapp/core/domain/geo_point.dart';
import 'package:flutter_test/flutter_test.dart';

GeoPoint point(double lat, double lng) => (lat: lat, lng: lng);

void main() {
  group('haversineDistanceM — analytic spherical-Earth cases', () {
    test('1 degree along the equator', () {
      // 1° arc = R·π/180 on a 6371 km sphere.
      expect(haversineDistanceM(point(0, 0), point(0, 1)),
          closeTo(111194.93, 1));
    });

    test('1 degree of pure latitude (same meridian)', () {
      // On a sphere, 1° of latitude arc equals 1° of equatorial arc.
      expect(haversineDistanceM(point(0, 0), point(1, 0)),
          closeTo(111194.93, 1));
    });

    test('quarter circumference poleward', () {
      expect(haversineDistanceM(point(0, 0), point(0, 90)),
          closeTo(10007543.40, 1));
      expect(haversineDistanceM(point(0, 0), point(90, 0)),
          closeTo(10007543.40, 1));
    });

    test('negative direction and symmetry', () {
      expect(haversineDistanceM(point(0, 0), point(0, -1)),
          closeTo(111194.93, 1));
      expect(haversineDistanceM(point(10, 20), point(30, 40)),
          closeTo(haversineDistanceM(point(30, 40), point(10, 20)), 1));
    });

    test('same point is zero', () {
      expect(haversineDistanceM(point(22.7775, 73.6177), point(22.7775, 73.6177)),
          closeTo(0, 0.001));
    });
  });

  group('haversineDistanceM — known Gujarat coordinate pairs', () {
    test('Godhra → Ahmedabad ≈ 110.6 km straight line', () {
      // Cross-checked against an independent spherical law of cosines
      // implementation; geographically sane driving-straight-line value.
      expect(
        haversineDistanceM(point(22.7775, 73.6177), point(23.0225, 72.5714)),
        closeTo(110581.62, 1),
      );
    });

    test('Godhra → Vadodara ≈ 68.9 km straight line', () {
      expect(
        haversineDistanceM(point(22.7775, 73.6177), point(22.3072, 73.1812)),
        closeTo(68878.99, 1),
      );
    });

    test('1° of latitude at Godhra ≈ 111.2 km', () {
      expect(
        haversineDistanceM(point(22.7775, 73.6177), point(23.7775, 73.6177)),
        closeTo(111194.93, 1),
      );
    });
  });

  group('isWithinWard / markDecision — flagged inside and outside radius', () {    final wardCenter = point(22.7, 73.6);
    const radiusM = 300.0;

    test('well inside the radius → not flagged', () {
      // ~111 m north of the centre.
      final inside = point(wardCenter.lat + 0.001, wardCenter.lng);
      expect(isWithinWard(inside, wardCenter, radiusM), isTrue);
      expect(markDecision(inside, wardCenter, radiusM).flagged, isFalse);
      expect(markDecision(inside, wardCenter, radiusM).withinRadius, isTrue);
    });

    test('well outside the radius → flagged, but the mark is still a decision',
        () {
      // ~333.6 m north of the centre.
      final outside = point(wardCenter.lat + 0.003, wardCenter.lng);
      expect(isWithinWard(outside, wardCenter, radiusM), isFalse);
      final d = markDecision(outside, wardCenter, radiusM);
      expect(d.flagged, isTrue);
      expect(d.withinRadius, isFalse);
    });

    test('just inside and just outside the boundary split correctly', () {
      // ~296.5 m (inside) and ~303.6 m (outside) from the centre.
      expect(
          markDecision(point(wardCenter.lat + 296.5 / 111194.93, wardCenter.lng),
                  wardCenter, radiusM)
              .flagged,
          isFalse);
      expect(
          markDecision(point(wardCenter.lat + 303.5 / 111194.93, wardCenter.lng),
                  wardCenter, radiusM)
              .flagged,
          isTrue);
    });

    test('position exactly on the centre with zero radius is inside', () {
      expect(isWithinWard(wardCenter, wardCenter, 0), isTrue);
    });

    test('flagged is simply the negation of withinRadius', () {
      final far = point(0, 0);
      expect(markDecision(far, wardCenter, radiusM).flagged,
          !isWithinWard(far, wardCenter, radiusM));
    });
  });
}
