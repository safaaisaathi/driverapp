/// Straight-line geographic helpers used by the Write Policy and Mark Ward
/// Done (PRD-2 sections 0.13 and 3, Behaviour rules).
library;

import 'geo_point.dart';

import 'dart:math' as math;

/// Mean Earth radius in metres, the standard spherical-earth approximation.
const double _earthRadiusM = 6371000.0;

/// Great-circle distance between two points, in metres (Haversine formula,
/// spherical Earth of radius 6371 km). Pure and total: accepts any lat/lng.
double haversineDistanceM(GeoPoint a, GeoPoint b) {
  final phiA = _degToRad(a.lat);
  final phiB = _degToRad(b.lat);
  final deltaPhi = phiB - phiA;
  final deltaLambda = _degToRad(b.lng - a.lng);

  final h = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
      math.cos(phiA) * math.cos(phiB) *
          math.sin(deltaLambda / 2) * math.sin(deltaLambda / 2);
  return 2 * _earthRadiusM * math.asin(math.sqrt(h));
}

/// Whether [position] is within [radiusM] metres (straight-line, inclusive
/// edge) of the ward centre. PRD-2 F-D3: distance to the ward `center`
/// against `radiusM`.
bool isWithinWard(GeoPoint position, GeoPoint wardCenter, double radiusM) {
  return haversineDistanceM(position, wardCenter) <= radiusM;
}

/// Result of applying the Mark Ward Done distance rule.
typedef MarkDecision = ({bool withinRadius, bool flagged});

/// Flags a Mark Ward Done: `flagged = !isWithinWard` (PRD-2 section 3,
/// Behaviour rules — outside the ward radius still allows the mark but keeps
/// the entry for admin review).
MarkDecision markDecision(GeoPoint position, GeoPoint wardCenter, double radiusM) {
  final within = isWithinWard(position, wardCenter, radiusM);
  return (withinRadius: within, flagged: !within);
}

double _degToRad(double deg) => deg * math.pi / 180.0;
