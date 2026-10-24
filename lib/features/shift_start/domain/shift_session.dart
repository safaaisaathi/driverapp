/// The running shift's identity (F-D1 → F-D2 seam, PRD-2 0.13).
///
/// D1 sets this "shift-active" state natively so the background tracking
/// engine (F-D2, ticket 05) can hook straight into it — the service
/// itself is NOT implemented here.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The live trip record of the current shift (Glossary): everything the
/// tracking engine needs at handover.
final class ShiftSession {
  const ShiftSession({
    required this.vanId,
    required this.tripId,
    required this.routeId,
    required this.startedAt,
    required this.date,
  });

  /// `vans/{vanId}` — the shift's van.
  final String vanId;

  /// `trips/{tripId}` — the (already created or resumed) trip doc,
  /// `vans.currentTripId` points here.
  final String tripId;

  /// `vans.routeId` — the route served this shift.
  final String routeId;

  /// `trips.startedAt` (the existing trip's when resumed).
  final DateTime startedAt;

  /// `trips.date` — the collection-day calendar date 00:00 IST
  /// ([utcStartOfIstDay] of shift start).
  final DateTime date;

  @override
  String toString() =>
      'ShiftSession($vanId, $tripId, $routeId, $startedAt, $date)';
}

/// Holds the session for F-D2's engine. `null` = no shift running.
/// Set by D1's flow controller; End Shift (F-D5) clears it.
// Not `final`: the engine ticket extends/adjusts the hinge if needed.
class ShiftController extends Notifier<ShiftSession?> {
  @override
  ShiftSession? build() => null;

  /// Marks the shift active; the engine consumes the returned-adjacent
  /// state from any screen via the provider.
  void activate(ShiftSession session) => state = session;

  /// Marks the shift over (End Shift, F-D5).
  void end() => state = null;
}

final shiftControllerProvider =
    NotifierProvider<ShiftController, ShiftSession?>(ShiftController.new);
