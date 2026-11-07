import '../models/models.dart';

/// Data access for the `trips` collection (0.2, 0.13, CHG-0003, CHG-0005).
///
/// The trip is SERVER-OWNED: `startShift`, `endShift` and `markWardDone` are
/// callables because the duplicate-trip race is real and the shift markers
/// belong to the server (02-contracts/callables.json). This interface is
/// therefore read-only, with ONE write: the trail chunk.
///
/// The trail is the contract's one documented direct-write exception: the
/// points land in `trips/{tripId}/trail/{n}` chunks of at most 1000
/// (`trailChunk.schema.json`), never in the legacy `trips.gpsTrail` array
/// (CHG-0005).
abstract class TripsRepository {
  /// Appends trail points as `trail` chunks of at most [trailChunkMaxPoints]
  /// each. Chunk documents are `{points, from, to}` where `from`/`to` are
  /// indexes in the trip's full trail.
  Future<void> appendGpsTrail(String tripId, List<GpsPoint> points);

  /// Reads one trip doc once (`null` when it vanished). The resume branch
  /// reattaches to the existing trip through this read (F-D1, ticket 04)
  /// so the fresh `ShiftSession` carries the trip's exact identity.
  Future<Trip?> readTrip(String tripId);

  /// Watches one trip doc by id (`null` when it vanished). The live route
  /// screen follows `vans/{vanId}.currentTripId` through this, so a shift
  /// that started before IST midnight (its `date` is yesterday) still reads
  /// as the open trip.
  Stream<Trip?> watchTrip(String tripId);

  /// Watch today's trip for [vanId]: the open (or just-closed) trip whose
  /// `date` is [date] — the fallback for a van doc without a marker, and the
  /// End Shift summary's source.
  Stream<Trip?> watchTripByVanIdAndDate({
    required String vanId,
    required DateTime date,
  });

  /// The most recent trips of [vanId] as of [asOfDate] — the Trip
  /// History screen (wireframe WF-22: Today / Yesterday rows; a still
  /// open trip shows as "running"). Read-only.
  Stream<List<Trip>> watchRecentTrips({
    required String vanId,
    required DateTime asOfDate,
    int limit = 30,
  });
}

/// The contract's chunk cap (`trailChunk.schema.json` `points.maxItems`).
const int trailChunkMaxPoints = 1000;
