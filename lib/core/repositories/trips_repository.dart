import '../models/models.dart';

/// Data access for the `trips` collection (0.2, 0.13).
///
/// Trip is the log record of one shift (Glossary). The driver app creates it
/// at shift start, appends Mark Ward Done entries and Trail batches while on
/// shift, and closes it at End Shift. `trips.alertedWardIds` is written by the
/// backend's `arrivalAlert` (0.7) — the driver app never rewrites it, so this
/// interface deliberately has no setter for it (0.15.4 gaps are listed in the
/// ticket report, not improvised).
abstract class TripsRepository {
  /// Creates the trip doc and returns the created Trip with its contract `id`
  /// filled in.
  Future<Trip> createTrip(Trip trip);

  /// Appends one Mark Ward Done entry to `trips.wardsDone`.
  Future<void> appendWardDone(String tripId, WardDone entry);

  /// Appends a batch of buffered Trail points to `trips.gpsTrail` in one
  /// write (0.13 Flow A step 4: every 30 s the buffered points are appended).
  Future<void> appendGpsTrail(String tripId, List<GpsPoint> points);

  /// Sets `trips.endedAt` (End Shift).
  Future<void> setEndedAt(String tripId, DateTime endedAt);

  /// Sets `trips.mockLocationDetected` (grilled decision: mock-location admin
  /// notification is written here, the push side is a backend concern).
  Future<void> setMockLocationDetected(
    String tripId, {
    required bool detected,
  });

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
  /// `date` is [date] — the resume-never-duplicate seam and the live route
  /// screen both read through this.
  Stream<Trip?> watchTripByVanIdAndDate({
    required String vanId,
    required DateTime date,
  });

  /// The most recent trips of [vanId] as of [asOfDate] — the Trip
  /// History screen (wireframe WF-22: Today / Yesterday rows; a still
  /// open trip shows as "running"). Read-only: trips are created by
  /// this app's shift flow, never issued from the history screen.
  Stream<List<Trip>> watchRecentTrips({
    required String vanId,
    required DateTime asOfDate,
    int limit = 30,
  });
}
