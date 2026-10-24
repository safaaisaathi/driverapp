import '../models/models.dart';

/// Data access for the `vans` collection (0.2, 0.13).
///
/// All the reads/writes the driver app performs on one van: the van list for
/// the picker, the single-van watcher for the live route screen, and the
/// driver-scoped writes (`lastLocation`, `status`, `batteryPct` per 0.8).
/// Implementations must never leak Firebase types into widgets (0.11).
abstract class VansRepository {
  /// Reads the van list (id, plateNo, routeId, status, lastLocation) for the
  /// van-picker screen.
  Future<List<Van>> readVans();

  /// Watch one van doc; emits `null` only before the doc exists.
  Stream<Van?> watchVan(String vanId);

  /// Writes `{lat,lng,updatedAt,speedKmph}` to `vans/{vanId}.lastLocation`
  /// (Flow A step 3). When [updatedAt] is omitted the server timestamp is
  /// used, matching 0.13 ("updatedAt (server timestamp)").
  Future<void> updateLastLocation({
    required String vanId,
    required double lat,
    required double lng,
    required double speedKmph,
    DateTime? updatedAt,
  });

  /// Sets `vans.status` (idle | on_shift | offline); only the driver's own
  /// session may write it (0.8).
  Future<void> updateStatus(String vanId, VanStatus status);

  /// Sets `vans.batteryPct` for the low-battery GPS interval (0.13).
  Future<void> updateBatteryPct(String vanId, int batteryPct);
}
