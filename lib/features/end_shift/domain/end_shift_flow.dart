/// End Shift (ticket 08, PRD-2 F-D5 / DESIGN §9.10, CHG-0003).
///
/// Summary → confirm → success, all through the state the app already
/// watches: the open trip and the shift session. The confirm performs the
/// server-owned close:
/// 1. the `endShift` callable closes `trips` and clears `vans.currentTripId`,
/// 2. stop the tracking engine (persistent-notification service on device),
/// 3. clear the shift session.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driverapp/core/contract/gateway_providers.dart';
import 'package:driverapp/core/domain/end_shift_writes.dart';
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
        gateway: ref.read(shiftGatewayProvider),
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
