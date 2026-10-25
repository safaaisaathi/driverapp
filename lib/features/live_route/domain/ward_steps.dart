/// Ordered ward steps for the Live Route screen (PRD-2 F-D3 step 1: D2 shows
/// `routes.wardIds` in order with names, the next ward highlighted).
///
/// Pure list logic only — no map widgets, no Firebase, no Riverpod. The
/// Riverpod layer turns repository data into this shape; the screen only
/// renders it.
library;

import 'package:driverapp/core/domain/ward_order.dart';
import 'package:driverapp/core/models/models.dart';

/// One row of the route's visit order: the ward, its position in
/// `routes.wardIds` (first occurrence wins — ruling 5), whether it is done
/// in today's trip, whether it is the next-in-order ward, and whether its
/// Mark Ward Done was flagged (kept visible for the driver's own record —
/// the flag itself is the contract shape 0.2 `{wardId, doneAt, flagged}`).
class WardStep {
  final Ward ward;

  /// Position in `routes.wardIds` (0-based, first occurrence — ruling 5).
  final int orderIndex;

  final bool isDone;

  /// The first undone ward in route order (ruling 5 via `ward_order.dart`);
  /// only meaningful while [isDone] is false.
  final bool isNext;

  final bool isFlagged;

  const WardStep({
    required this.ward,
    required this.orderIndex,
    required this.isDone,
    required this.isNext,
    required this.isFlagged,
  });

  @override
  bool operator ==(Object other) =>
      other is WardStep &&
      other.runtimeType == runtimeType &&
      other.ward == ward &&
      other.orderIndex == orderIndex &&
      other.isDone == isDone &&
      other.isNext == isNext &&
      other.isFlagged == isFlagged;

  @override
  int get hashCode =>
      Object.hash(runtimeType, ward, orderIndex, isDone, isNext, isFlagged);

  @override
  String toString() =>
      'WardStep(${ward.id}@$orderIndex done=$isDone next=$isNext flagged=$isFlagged)';
}

/// Builds the route's [WardStep]s in `routes.wardIds` order.
///
/// - Done set comes from `trips.wardsDone` of today's open trip; ids done in
///   the trip but not on the route are ignored (they cannot be rendered).
/// - Unknown ward ids (id on the route, no `wards` doc resolved) are absent
///   from the result — the repository's own docs say missing ids are simply
///   dropped by the load.
/// - Duplicate ward ids on the route: every occurrence renders in its own
///   place, but `isNext`/flags evaluate by the [ward_order.dart] rules, where
///   the first occurrence wins.
List<WardStep> deriveWardSteps({
  required List<String> orderedWardIds,
  required Map<String, Ward> wardsById,
  required TripDoneState done,
}) {
  final nextId = nextUndoneWardId(orderedWardIds, done.doneIds);
  return [
    for (final entry in orderedWardIds.indexed)
      if (wardsById[entry.$2] != null)
        WardStep(
          ward: wardsById[entry.$2]!,
          orderIndex: entry.$1,
          isDone: done.doneIds.contains(entry.$2),
          isNext: entry.$2 == nextId,
          isFlagged: done.flaggedIds.contains(entry.$2),
        ),
  ];
}

/// Done ids from today's `trips.wardsDone`, reduced to a `Set<String>` with a
/// per-id flagged lookup. The done set is contract-wide deduped by `wardId`
/// (client dedupes on mark — ruling 13) so a retried/replayed duplicate entry
/// changes nothing.
class TripDoneState {
  final Set<String> doneIds;

  /// The ids marked flagged in this trip (outside-radius Mark Ward Done).
  final Set<String> flaggedIds;

  const TripDoneState(this.doneIds, this.flaggedIds);

  /// Extracts the state from [trip]; a null trip (no open trip today) means
  /// nothing done yet.
  factory TripDoneState.of(Trip? trip) {
    if (trip == null) return const TripDoneState({}, {});
    final flagged = <String>{};
    final done = <String>{};
    for (final entry in trip.wardsDone) {
      // First entry per ward wins (ruling 13 dedupe view).
      if (done.add(entry.wardId) && entry.flagged) flagged.add(entry.wardId);
    }
    return TripDoneState(done, flagged);
  }

  @override
  bool operator ==(Object other) =>
      other is TripDoneState &&
      other.runtimeType == runtimeType &&
      other.doneIds.length == doneIds.length &&
      other.doneIds.containsAll(doneIds) &&
      other.flaggedIds.length == flaggedIds.length &&
      other.flaggedIds.containsAll(flaggedIds);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        Object.hashAll(doneIds),
        Object.hashAll(flaggedIds),
      );

  @override
  String toString() => 'TripDoneState($doneIds flagged: $flaggedIds)';
}
