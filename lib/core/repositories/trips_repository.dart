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

  /// Watch today's trip for [vanId]: the open (or just-closed) trip whose
  /// `date` is [date] — the resume-never-duplicate seam and the live route
  /// screen both read through this.
  Stream<Trip?> watchTripByVanIdAndDate({
    required String vanId,
    required DateTime date,
  });
}
