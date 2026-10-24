/// The contract's location shape `{lat: number, lng: number}` (0.2, 0.13).
///
/// Used for `wards.center` and `complaints.location`. Field names are
/// contractual — do not rename (rule 0.15.4).
library;

class LocationPoint {
  final double lat;

  final double lng;

  const LocationPoint({required this.lat, required this.lng});

  factory LocationPoint.fromMap(Map<String, Object?> map) {
    final lat = map['lat'];
    final lng = map['lng'];
    if (lat is! num || lng is! num) {
      throw const FormatException(
        'location doc map does not match {lat,lng} shape (0.2)',
      );
    }
    return LocationPoint(lat: lat.toDouble(), lng: lng.toDouble());
  }

  Map<String, Object?> toMap() => {'lat': lat, 'lng': lng};

  @override
  bool operator ==(Object other) =>
      other is LocationPoint &&
      other.runtimeType == runtimeType &&
      other.lat == lat &&
      other.lng == lng;

  @override
  int get hashCode => Object.hash(runtimeType, lat, lng);

  @override
  String toString() => 'LocationPoint(lat: $lat, lng: $lng)';
}
