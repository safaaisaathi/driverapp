/// End Shift (ticket 08, PRD-2 F-D5 / DESIGN §9.10).
///
/// Summary → confirm → success, all through the state the app already
/// watches: the open trip and the shift session. The confirm performs
/// exactly the PRD's end-shift write set:
/// 1. `trips.endedAt` = now (trail flush already happens batch-wise in the
///    tracking engine; the engine's stop is called below too),
/// 2. `vans.status = idle`,
/// 3. `vans.currentTripId = null`,
/// 4. stop the tracking engine (persistent-notification service on device),
/// 5. clear the shift session.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driverapp/core/domain/end_shift_writes.dart';
import 'package:driverapp/core/repositories/repository_providers.dart';
import 'package:driverapp/features/shift_start/domain/shift_session.dart';
import 'package:driverapp/features/tracking/tracking_providers.dart';

enum EndShiftPhase { summary, ending, ended, failed }

final endShiftFlowProvider =
    NotifierProvider<EndShiftController, EndShiftPhase>(
  EndShiftController.new,
);

class EndShiftController extends Notifier<EndShiftPhase> {
  @override
  EndShiftPhase build() => EndShiftPhase.summary;

  Future<void> confirmEnd() async {
    state = EndShiftPhase.ending;
    final session = ref.read(shiftControllerProvider);
    if (session == null) {
      // Nothing to write (defensive; D1 should always have built one):
      // treat it as done so the screen never wedges on `ending`.
      state = EndShiftPhase.ended;
      return;
    }
    try {
      await writeEndShift(
        vans: ref.read(vansRepositoryProvider),
        trips: ref.read(tripsRepositoryProvider),
        vanId: session.vanId,
        tripId: session.tripId,
        stopTracking: () => ref.read(trackingEngineProvider).stop(),
      );
      ref.read(shiftControllerProvider.notifier).end();
      state = EndShiftPhase.ended;
    } catch (_) {
      state = EndShiftPhase.failed;
    }
  }
}
