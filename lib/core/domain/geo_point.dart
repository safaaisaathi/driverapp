/// A geographic position as latitude/longitude degrees.
///
/// The shape the contract uses for ward centres and van positions
/// (`wards.center`, `vans.lastLocation` — PRD-2 section 0.13). A record is
/// used so structural equality and `hashCode` come for free.
typedef GeoPoint = ({double lat, double lng});
