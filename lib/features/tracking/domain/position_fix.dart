/// A single GPS fix fed into the tracking engine (PRD-2 F-D2).
///
/// A plain value type so the engine can be tested against fake position
/// streams without any geolocator types (spec seam discipline: platform
/// channels live behind injectable interfaces).
class VanFix {
  final double lat;

  final double lng;

  /// Speed in km/h derived from the GPS speed (m/s); clamped to >= 0
  /// because Android reports -1.0 for "speed unavailable".
  final double speedKmph;

  /// When the fix was taken (device clock; trail point `t`).
  final DateTime t;

  const VanFix({
    required this.lat,
    required this.lng,
    required this.speedKmph,
    required this.t,
  });

  @override
  String toString() =>
      'VanFix(lat: $lat, lng: $lng, speedKmph: $speedKmph, t: $t)';
}
