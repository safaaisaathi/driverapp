/// Mark Ward Done write flow (ticket 07, PRD-2 F-D3 step 2 + section 3
/// "Mark Ward Done").
///
/// One Riverpod notifier drives the driver's write path: append
/// `{wardId, doneAt, flagged}` into `trips.wardsDone` of TODAY'S open trip
/// — through the trips repository ONLY ([TripsRepository.appendWardDone]),
/// never a route/ward/van doc write (0.8 driver write scope).
///
/// ### Guard and decision seams
///
/// - **Open trip**: read (VALUE, never `.future` — the autoDispose stream
///   wedge, ticket 06's lesson) from [openTripProvider] — the same watch
///   the screen renders from. The UI disables the mark controls while
///   there is no open trip; [mark] re-checks defensively.
/// - **Flag decision**: the ward's `centre`/`radiusM` against the van's
///   last-known position through the pure domain helper `markDecision`
///   (`core/domain/geo.dart`). The position comes from the van-doc stream —
///   the SAME data the map marker renders (the tracking engine's hot fix
///   has no exposure seam yet; D2's latest write is ≤ 30 s old, the Write
///   Policy heartbeat). No position fix yet cannot prove "inside", so the
///   entry is conservatively `flagged: true` — flagged is the admin-review
///   channel, never a silent "honest" claim.
/// - **Idempotency** (ruling 13): a tapped ward already done in this trip
///   is SKIPPED — tapping twice must not duplicate. In-flight ids disable
///   their own control first (the widget layer), re-entrantly too.
///
/// ### No local caching of "done"
///
/// The flow keeps ONLY write-process state ([MarkWardDoneFlow.inFlight],
/// [MarkWardDoneFlow.writeFailed]). The done tick and the next-chip move
/// come purely from the open-trip stream the screen already watches — the
/// repository re-emission after the append is the single source of truth.
/// Offline changes nothing here: the append is a local Firestore write that
/// persistence queues in order (PRD-2 offline behaviour, F-D7); the offline
/// banner is the screen's concern, already wired in
/// `live_route_providers.dart`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driverapp/core/domain/geo.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repositories.dart';

import 'domain/ward_steps.dart';
import 'live_route_providers.dart';

/// The write-process state of the mark action. NOT the done state — ticks
/// and the next chip render exclusively from the open-trip stream.
class MarkWardDoneFlow {
  /// Ward ids with an append in flight — those rows' controls disable so
  /// one tap cannot double-write.
  final Set<String> inFlight;

  /// True after the LAST attempt's append failed. The screen shows one
  /// boring localized message; the next tap attempt (the retry) or a later
  /// success clears it. No tick ever appears from a failed write — nothing
  /// is cached done.
  final bool writeFailed;

  const MarkWardDoneFlow({
    this.inFlight = const <String>{},
    this.writeFailed = false,
  });

  MarkWardDoneFlow copyWith({Set<String>? inFlight, bool? writeFailed}) =>
      MarkWardDoneFlow(
        inFlight: inFlight ?? this.inFlight,
        writeFailed: writeFailed ?? this.writeFailed,
      );
}

/// Riverpod wiring for the mark flow (0.11: writes only through the
/// repository seam; feature tests override the repositories, never this
/// notifier — see test/live_route/mark_ward_done_test.dart).
final markWardDoneFlowProvider =
    NotifierProvider.autoDispose<MarkWardDoneController, MarkWardDoneFlow>(
      MarkWardDoneController.new,
    );

/// Drives the Mark Ward Done writes (public method = the tap event).
class MarkWardDoneController extends Notifier<MarkWardDoneFlow> {
  // State writes after dispose (screen unmounted mid-write) must not throw.
  bool _disposed = false;

  @override
  MarkWardDoneFlow build() {
    ref.onDispose(() => _disposed = true);
    return const MarkWardDoneFlow();
  }

  // Imperative reads (the PendingReportsFlowController pattern): taps drive
  // this controller; repository providers must NOT rebuild it — a rebuild
  // would reset [state] mid-flight and drop the in-flight guard.
  TripsRepository get _trips => ref.read(tripsRepositoryProvider);

  void _set(MarkWardDoneFlow flow) {
    if (!_disposed) state = flow;
  }

  void _dropInFlight(String wardId, {bool failed = false}) {
    if (_disposed) return;
    // Other wards' in-flight marks stay (concurrent taps on two rows).
    state = MarkWardDoneFlow(
      inFlight: <String>{
        for (final id in state.inFlight)
          if (id != wardId) id,
      },
      // Success clears any past failure note; a failure shows it. The
      // attempt itself already reset it at mark() start (the retry).
      writeFailed: failed,
    );
  }

  /// Tapped "this ward is done" for [wardId] on the van [vanId]'s shift —
  /// the big next-ward button and the smaller out-of-order control both
  /// land here. Never throws: a failed append surfaces as
  /// [MarkWardDoneFlow.writeFailed].
  Future<void> mark(String vanId, String wardId) async {
    if (state.inFlight.contains(wardId)) return; // double-tap re-entrancy
    _set(
      state.copyWith(
        inFlight: <String>{...state.inFlight, wardId},
        writeFailed: false, // this attempt IS the retry
      ),
    );

    final trip = ref.read(openTripProvider(vanId)).value;
    if (trip == null) {
      // No open trip today — the UI already disables the controls with the
      // hint; nothing must be written anywhere (contract: wardsDone of
      // TODAY'S open trip only).
      _dropInFlight(wardId);
      return;
    }
    // Ruling 13: the client dedupes by wardId — an already-done ward never
    // duplicates (the re-emission may not have reached the widget yet).
    if (TripDoneState.of(trip).doneIds.contains(wardId)) {
      _dropInFlight(wardId);
      return;
    }

    final ward = (ref.read(routeWardsProvider(vanId)).value ?? const <Ward>[])
        .where((candidate) => candidate.id == wardId)
        .firstOrNull;
    if (ward == null) {
      // Ghost tap (a row cannot render without its wards doc in the first
      // place) — degraded write, boring message row.
      _dropInFlight(wardId, failed: true);
      return;
    }

    // The flag decision (seam 2 pure helper): the van's last-known position
    // vs the ward centre/radius. A null fix cannot prove "inside" → flagged
    // (candidate ruling: unknown position = outside for review purposes).
    final fix = ref.read(vanDocProvider(vanId)).value?.lastLocation;
    final decision = fix == null
        ? (withinRadius: false, flagged: true)
        : markDecision(
            (lat: fix.lat, lng: fix.lng),
            (lat: ward.center.lat, lng: ward.center.lng),
            ward.radiusM,
          );

    try {
      // The ONLY write (0.2 shape, exact fields): `trips.wardsDone` gains
      // {wardId, doneAt, flagged}. No route/ward/van doc is touched. The
      // trip id comes from the open-trip watch itself. Offline is fine —
      // the write is local and the persistence queue syncs in order (F-D7).
      await _trips.appendWardDone(
        trip.id,
        WardDone(
          wardId: wardId,
          doneAt: DateTime.now(),
          flagged: decision.flagged,
        ),
      );
      _dropInFlight(wardId);
    } on Exception {
      // The append failed (dead-zone hard error) — NOTHING is cached done;
      // the boring message shows and the driver taps again.
      _dropInFlight(wardId, failed: true);
    }
  }
}
