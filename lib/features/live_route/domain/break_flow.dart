/// Local-only break state (wireframe WF-25).
///
/// A break pauses the shift locally — `van.status` is NOT written because
/// the contract enum is only `idle`/`on_shift`/`offline` (break is a
/// driver-facing pause, not a status change). No backend surface: this is
/// in-session Riverpod state for the demo slice.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BreakPhase { notOnBreak, onBreak }

final class BreakState {
  const BreakState({this.phase = BreakPhase.notOnBreak, this.startedAt});
  final BreakPhase phase;
  final DateTime? startedAt;

  /// Elapsed break time (live-derived, not stored).
  Duration get elapsed =>
      startedAt == null ? Duration.zero : DateTime.now().difference(startedAt!);
}

/// The break controller: start / end a locally-paused shift.
class BreakController extends Notifier<BreakState> {
  @override
  BreakState build() => const BreakState();

  /// Begin a break. Elapsed time is derived from [startedAt].
  void start() => state = BreakState(phase: BreakPhase.onBreak, startedAt: DateTime.now());

  /// End the break and resume the shift.
  void end() => state = const BreakState();

  /// Time elapsed since the break started.
  Duration get elapsed => state.elapsed;
}

final breakControllerProvider =
    NotifierProvider<BreakController, BreakState>(BreakController.new);

/// Local-only skipped-ward state (wireframe WF-24).
///
/// Skipping a ward drops it from today's route locally — it must NEVER
/// corrupt `trips.wardsDone` (the source of truth stays the shift's trip).
/// This is in-session state for the demo slice; no backend write.
final class SkipWardState {
  const SkipWardState({this.skippedWardIds = const <String>{}});
  final Set<String> skippedWardIds;
}

/// Tracks wards the driver has skipped this shift.
class SkipWardController extends Notifier<SkipWardState> {
  @override
  SkipWardState build() => const SkipWardState();

  /// Mark [wardId] as skipped this shift (local only).
  void skip(String wardId) =>
      state = SkipWardState(skippedWardIds: <String>{...state.skippedWardIds, wardId});

  /// Whether [wardId] is skipped this shift.
  bool isSkipped(String wardId) => state.skippedWardIds.contains(wardId);
}

final skipWardControllerProvider =
    NotifierProvider<SkipWardController, SkipWardState>(SkipWardController.new);
