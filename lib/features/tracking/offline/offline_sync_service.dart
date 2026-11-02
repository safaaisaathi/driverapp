/// Offline sync service (F-D7): drains the durable queue IN ORDER when the
/// network is back.
///
/// On every reconnect event (and on a manual [flushNow]):
/// 1. the latest queued `vans.lastLocation` candidate is sent ONCE through
///    `VansRepository.updateLastLocation` (omitted `updatedAt` = server
///    timestamp; 0.13) — a failed send goes back to the queue unless a
///    newer candidate replaced it meanwhile ("never re-send an older
///    lastLocation after a newer one landed", 0.13 note);
/// 2. the last-attached trip's Trail buffer is drained through
///    `TripsRepository.appendGpsTrail`, the SAME repository append pattern
///    the engine flush uses, so catch-up data keeps the 30 s batch shape:
///    every catch-up append is one ordered single `appendGpsTrail` write
///    (several ordered appends when the backlog exceeds
///    [maxCatchUpBatchPoints] — appended ruling below). A failed append
///    puts its whole batch back at the FRONT of the buffer, order
///    preserved, so nothing is silently dropped.
///
/// All counts (un-synced points volume, surfaced subtly — no alarm spam)
/// stream through [pendingCountStream].
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repositories.dart';

import '../domain/trail_buffer.dart';
import 'connectivity_source.dart';
import 'offline_write_queue.dart';

/// Catch-up append cap (ticket 12 ruling): a catch-up append stays an
/// ordered single `appendGpsTrail` call, chunked at this many points to
/// bound the batch write size; chunk boundaries never change point order.
const int maxCatchUpBatchPoints = 500;

class OfflineSyncService {
  OfflineSyncService({
    required VansRepository vansRepository,
    required TripsRepository tripsRepository,
    required OfflineWriteQueue writeQueue,
    required ConnectivitySource connectivitySource,
    required TrailBufferFactory trailBufferFactory,

    /// Test override of the catch-up batch cap (defaults to
    /// [maxCatchUpBatchPoints]).
    int? catchUpBatchPoints,
  }) : _vans = vansRepository,
       _trips = tripsRepository,
       _connectivity = connectivitySource,
       // ignore: prefer_initializing_formals
       _writeQueue = writeQueue,
       // ignore: prefer_initializing_formals
       _trailBufferFactory = trailBufferFactory,
       _catchUpBatchPoints = catchUpBatchPoints ?? maxCatchUpBatchPoints;

  final VansRepository _vans;
  final TripsRepository _trips;
  final OfflineWriteQueue _writeQueue;
  final ConnectivitySource _connectivity;
  final TrailBufferFactory _trailBufferFactory;
  final int _catchUpBatchPoints;

  StreamSubscription<bool>? _connectivitySub;

  /// The trip whose trail is drained / counted: the LAST trip attached via
  /// [attachTrip]. Kept after detach on purpose — leftover trail points of
  /// a shift ended inside a dead zone must still sync (and still count).
  String? _tripId;

  bool _flushing = false;
  bool _flushAgain = false;

  /// Completes when the currently running flush drain (pass + every
  /// trailing pass concurrent callers requested meanwhile) is done. A
  /// caller of [flushNow] awaiting while a drain runs gets THIS future —
  /// otherwise an overlapping pass (e.g. the initial connectivity
  /// emission) would let an `await flushNow()` return before its own
  /// request has actually drained, and anything the caller does next
  /// (like a test closing Hive) races the still-running pass.
  Future<void> _drain = Future<void>.value();

  /// Last count pushed through the CHANGE stream (dedupe keeps a constant
  /// backlog from spamming an unchanged value; late subscribers still get
  /// the live value directly — see [pendingCountStream]).
  int _lastEmitted = 0;

  final _counts = StreamController<int>.broadcast();

  /// How many points are still un-synced: `0..1` destination candidates
  /// plus the attached trip's pending Trail points. Emits the CURRENT
  /// count on subscribe (late listeners never see stale data), then on
  /// every change. Subtle surface: a plain count, no alarm semantics.
  Stream<int> get pendingCountStream => Stream<int>.multi((controller) {
    final subscription = _counts.stream.listen(
      controller.add,
      onError: controller.addError,
    );
    controller.onCancel = () => subscription.cancel();
    // Late subscribers get the CURRENT count first, bypassing the change
    // dedupe (a badge must never wake up empty).
    unawaited(
      _computePendingCount().then((count) {
        if (!controller.isClosed) controller.add(count);
      }),
    );
  });

  /// One-shot read of the current un-synced count.
  Future<int> currentPendingCount() => _computePendingCount();

  /// Subscribe to connectivity; every online transition (and the initial
  /// state, per the source contract) triggers an in-order flush pass.
  void start() {
    if (_connectivitySub != null) return;
    _connectivitySub = _connectivity.status.listen(
      (online) => online ? unawaited(flushNow()) : _refreshCount(),
    );
  }

  /// Unsubscribes (the durable queue survives — nothing is dropped).
  void stop() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// Tells the service which trip's trail to drain/count. Call again when
  /// a new trip starts. No detach by design (see the class doc).
  void attachTrip(String tripId) {
    _tripId = tripId;
    _refreshCount();
  }

  /// The trip currently attached for catch-up drain, or `null` before the
  /// first [attachTrip]. Test seam for the start/resume wiring.
  @visibleForTesting
  String? get attachedTripId => _tripId;

  /// Flush pass, safe to call concurrently (one pass runs at a time; a
  /// concurrent call's returned future completes after the trailing pass
  /// it requested finishes — callers can always `await flushNow()` and be
  /// sure their request drained, not just that some pass was in flight).
  Future<void> flushNow() {
    if (_flushing) {
      _flushAgain = true;
      return _drain;
    }
    _flushing = true;
    final done = Completer<void>();
    _drain = done.future;
    unawaited(_drainAllPasses(done));
    return _drain;
  }

  /// Runs passes until no trailing request is left, then closes [done].
  Future<void> _drainAllPasses(Completer<void> done) async {
    while (true) {
      _flushAgain = false;
      await _flushPasses();
      if (!_flushAgain) break;
    }
    _flushing = false;
    done.complete();
  }

  // --------------------------------------------------------------------------
  // internals
  // --------------------------------------------------------------------------

  Future<void> _flushPasses() async {
    await _flushLastLocation();
    // Drain catch-up batches until the buffer is empty or a write fails;
    // on failure the batch is back at the FRONT and the loop stops (the
    // next online event or flushNow retries in the original order).
    while (await _flushTrailBatch()) {}
    await _refreshCount();
  }

  /// Sends the queued latest lastLocation candidate once.
  Future<void> _flushLastLocation() async {
    final candidate = await _writeQueue.takeLastLocation();
    if (candidate == null) return;
    try {
      await _vans.updateLastLocation(
        vanId: candidate.vanId,
        lat: candidate.lat,
        lng: candidate.lng,
        speedKmph: candidate.speedKmph,
      ); // updatedAt omitted → server timestamp (0.13)
    } catch (error) {
      await _writeQueue.putBackLastLocation(candidate);
      debugPrint('offline: lastLocation flush failed (kept queued): $error');
    }
    await _refreshCount();
  }

  /// One catch-up append: up to `_catchUpBatchPoints` oldest points, in
  /// order. Returns `true` when more may be pending, `false` when done.
  Future<bool> _flushTrailBatch() async {
    final tripId = _tripId;
    if (tripId == null) return false;

    TrailBuffer buffer;
    try {
      buffer = await _trailBufferFactory(tripId);
    } catch (error) {
      debugPrint('offline: trail buffer open failed: $error');
      return false;
    }

    List<GpsPoint> batch;
    try {
      batch = await buffer.takeOldest(limit: _catchUpBatchPoints);
    } catch (error) {
      debugPrint('offline: trail batch take failed: $error');
      return false;
    }
    if (batch.isEmpty) return false;

    try {
      await _trips.appendGpsTrail(tripId, batch);
    } catch (error) {
      await buffer.putBackOldest(batch); // FRONT, order preserved
      debugPrint('offline: trail append failed (re-queued): $error');
      await _refreshCount();
      return false;
    }
    await _refreshCount();
    return true;
  }

  /// Computes the count and pushes it only when it CHANGED (the change
  /// stream stays quiet about unchanged values; late subscribers get the
  /// live count directly via [pendingCountStream]).
  /// Best-effort count refresh (a badge must never crash the flush): the
  /// box can be legitimately closed underneath (app restart destroys the
  /// old service instance mid-read), so errors degrade to a log line.
  Future<void> _refreshCount() async {
    try {
      final count = await _computePendingCount();
      if (count == _lastEmitted) return;
      _lastEmitted = count;
      if (_counts.isClosed) return;
      _counts.add(count);
    } catch (error) {
      debugPrint('offline: pending count refresh failed: $error');
    }
  }

  Future<int> _computePendingCount() async {
    var count = await _writeQueue.pendingLastLocationCount;
    final tripId = _tripId;
    if (tripId == null) return count;
    try {
      final buffer = await _trailBufferFactory(tripId);
      count += buffer.pendingCount;
    } catch (error) {
      debugPrint('offline: trail count read failed: $error');
    }
    return count;
  }
}
