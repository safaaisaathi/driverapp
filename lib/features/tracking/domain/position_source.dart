/// Seam for the platform location stream: enables the tracking engine to run
/// against fakes in tests (F-D2; spec seam discipline).
library;

import 'position_fix.dart';

/// The minimum move distance between emitted fixes is chosen by the caller
/// (the engine passes [minMoveM], PRD-2 F-D2 step 3).
abstract class PositionSource {
  /// A live stream of fixes moved at least [distanceFilterM] from the
  /// previous emitted fix. Never completes; listeners must cancel.
  ///
  /// Errors surface on the stream (e.g. permission revoked mid-shift);
  /// the engine treats them as survivable and keeps waiting for the next fix.
  Stream<VanFix> fixes({required int distanceFilterM});
}
