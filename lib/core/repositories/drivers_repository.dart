import '../models/models.dart';

/// Data access for the `drivers` collection (0.16).
///
/// Read-only seam for the driver-identity flow: one fetch by raw code. The
/// repository normalizes the code internally (0.16: trim, uppercase, insert
/// dash) via [normalizeDriverCode], so a bad shape returns null and makes no
/// Firestore call. No active-filtering at this seam — the flow layer treats
/// `active = false` as not-found (tickets 4/5).
abstract class DriversRepository {
  /// Fetches `drivers/{normalizedCode}`; null for a bad shape or a missing
  /// doc.
  Future<Driver?> fetchDriver(String rawCode);
}
