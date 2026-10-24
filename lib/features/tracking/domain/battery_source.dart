/// Seam for battery reads (F-D8: low-battery interval fallback).
library;

/// One battery query per engine check. `null` means "unknown" — the Write
/// Policy treats unknown battery as healthy (never slows the van down).
abstract class BatterySource {
  /// Current battery percentage, `null` when unavailable. Must not throw:
  /// a dead battery API is the same as an unknown one.
  Future<int?> readBatteryPct();
}
