/// The tracking engine (F-D2 + F-D8 folded in; PRD-2 sections 0.13, 3, 5).
///
/// Responsibilities, in contract terms:
/// 1. Check the position every `gpsIntervalSec` (`gpsIntervalLowBatterySec`
///    when battery is below `lowBatteryPct`); each check applies the Write
///    Policy (`decideWrite`) to the latest fix.
/// 2. On `shouldWrite`: `vans.lastLocation = {lat,lng,updatedAt,speedKmph}`
///    (`updatedAt` omitted so the repository layer owns the server-timestamp
///    semantics) plus `vans.batteryPct` when known. Writes route ONLY
///    through repositories, never Firestore directly (spec seam 1).
/// 3. Buffer accepted points into a local Trail buffer and append
///    `trips.gpsTrail` in ONE batch every 30 s (plus a final flush at stop —
///    PRD-2 F-D2 step 4: "every 30 seconds and at End Shift").
/// 4. Resume: [startForActiveShift] reattaches to the open trip when
///    `vans.currentTripId != null` and `status == on_shift`, reading state
///    from the vans doc only (no PIN, no local session state).
/// 5. Flow F (silent van) driver-app side: when a write lands while the
///    backend has marked the van `offline`, the engine sets
///    `vans.status = on_shift` again (0.13 Flow F).
///
/// Platform channels (location stream, battery, foreground service, trail
/// box) are injectable seams: small interfaces in this folder, real
/// implementations under `data/` (spec: tests mock seams, never a device).
library;

import 'dart:async';

import 'package:flutter/foundation.dart'
    show debugPrint, visibleForTesting;
import 'package:driverapp/core/config/constants.dart';
import 'package:driverapp/core/domain/geo_point.dart';
import 'package:driverapp/core/domain/write_policy.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repositories.dart';

import '../offline/offline_write_queue.dart';
import 'battery_source.dart';
import 'foreground_service.dart';
import 'position_fix.dart';
import 'position_source.dart';
import 'trail_buffer.dart';

/// Seconds between trail flushes (PRD-2 0.13 Flow A step 4).
const int trailFlushIntervalSec = 30;

/// Hard cap for the local Trail buffer per trip: beyond this the OLDEST
/// points are dropped (developer ruling, ticket report — keeps a long
/// dead-zone from growing the batch beyond a healthy write size and memory
/// bounds; not a contract constant).
const int maxTrailBufferPoints = 5000;

/// Run status observable through [TrackingEngine.changes].
enum TrackingRunStatus {
  /// Not started, or stopped again by [TrackingEngine.stop].
  idle,

  /// A run is up: service started, stream and timers active.
  running,

  /// [TrackingEngine.start] failed before anything ran; `error` says why.
  failed,
}

class TrackingEngineState {
  final TrackingRunStatus status;

  final String? tripId;

  final String? vanId;

  /// True while the engine samples at `gpsIntervalLowBatterySec` (F-D8).
  final bool lowBatteryInterval;

  /// The error that put the engine into [TrackingRunStatus.failed], if any.
  final Object? error;

  const TrackingEngineState({
    required this.status,
    this.tripId,
    this.vanId,
    this.lowBatteryInterval = false,
    this.error,
  });

  static const TrackingEngineState idle = TrackingEngineState(
    status: TrackingRunStatus.idle,
  );

  @override
  String toString() =>
      'TrackingEngineState(status: $status, tripId: $tripId, vanId: $vanId, '
      'lowBatteryInterval: $lowBatteryInterval, error: $error)';
}

enum TrackingStartOutcome {
  started,

  /// Another run is already active; call [TrackingEngine.stop] first.
  alreadyRunning,

  /// The foreground service could not be started; nothing else was wired.
  serviceStartFailed,
}

class TrackingStartResult {
  final TrackingStartOutcome outcome;

  const TrackingStartResult(this.outcome);

  bool get isStarted => outcome == TrackingStartOutcome.started;

  @override
  String toString() => 'TrackingStartResult(${outcome.name})';
}

/// Resume outcome of [TrackingEngine.startForActiveShift]
/// (contract test: "resume without asking for the PIN again").
enum TrackingResumeOutcome {
  /// Tracking started against the open trip (`vans.currentTripId` with
  /// `status = on_shift`).
  resumed,

  /// The van doc shows no open shift — nothing to reattach to.
  notResumed,
}

class TrackingResumeResult {
  final TrackingResumeOutcome outcome;

  /// Open trip id (van doc `currentTripId` never invented) when [outcome]
  /// is [TrackingResumeOutcome.resumed].
  final String? tripId;

  const TrackingResumeResult({required this.outcome, this.tripId});

  bool get isResumed => outcome == TrackingResumeOutcome.resumed;
}

class TrackingEngine {
  TrackingEngine({
    required VansRepository vansRepository,
    required TripsRepository tripsRepository,
    required PositionSource positionSource,
    required BatterySource batterySource,
    required ForegroundServiceHandle serviceHandle,
    required TrailBufferFactory trailBufferFactory,
    DateTime Function()? clock,
    /// Test-only initial cadences; default to the contract constants.
    @visibleForTesting int? checkIntervalSec,
    @visibleForTesting int? flushIntervalSec,
    /// F-D7: when wired, a failed location write queues the LATEST candidate
    /// instead of being dropped (OfflineSyncService drains it on reconnect).
    OfflineWriteQueue? offlineWriteQueue,
  })  : _vans = vansRepository,
        _trips = tripsRepository,
        _position = positionSource,
        _battery = batterySource,
        _service = serviceHandle,
        _trailBufferFactory = trailBufferFactory, // ignore: prefer_initializing_formals
        _clock = clock ?? DateTime.now,
        _initialCheckInterval = checkIntervalSec ?? gpsIntervalSec,
        _flushIntervalSec = flushIntervalSec ?? trailFlushIntervalSec,
        _offlineWriteQueue = offlineWriteQueue; // ignore: prefer_initializing_formals

  final VansRepository _vans;
  final TripsRepository _trips;
  final PositionSource _position;
  final BatterySource _battery;
  final ForegroundServiceHandle _service;
  final TrailBufferFactory _trailBufferFactory;

  /// Injectable so tests run with a fake clock.
  final DateTime Function() _clock;

  /// Test-only cadence overrides (see constructor).
  final int _initialCheckInterval;
  final int _flushIntervalSec;

  /// F-D7 drain seam; null in tests that don't exercise the offline path.
  final OfflineWriteQueue? _offlineWriteQueue;

  TrackingEngineState _state = TrackingEngineState.idle;

  final _changes = StreamController<TrackingEngineState>.broadcast();

  /// Fires on every engine state change. Never errors.
  Stream<TrackingEngineState> get changes => _changes.stream;

  TrackingEngineState get state => _state;

  // ---- active run fields (null when idle) ----
  String? _tripId;
  String? _vanId;
  TrailBuffer? _trailBuffer;
  StreamSubscription<VanFix>? _fixSub;
  StreamSubscription<Van?>? _vanDocSub;
  Timer? _checkTimer;
  Timer? _flushTimer;
  int _intervalSec = gpsIntervalSec;
  GeoPoint? _lastWritten;
  DateTime? _lastWriteAt;
  VanFix? _latestFix;
  Van? _latestVan;
  bool _stopping = false;

  /// F-D9 local latch: avoids re-calling the repository write for every mock
  /// fix. NOT the ground truth — `trips.mockLocationDetected` in the trip doc
  /// is (kill/restart safe, never unset by the app). Latched here after the
  /// first mocked fix; a failed write re-arms the write for the next mock.
  bool _mockLocationLatched = false;

  /// Starts tracking for a trip the caller (D1 Start Shift) has just created
  /// after switching the van on_shift.
  ///
  /// The notification strings are the localized texts of the single allowed
  /// service notification ("Tracking active").
  Future<TrackingStartResult> start({
    required String tripId,
    required String vanId,
    required String notificationTitle,
    required String notificationBody,
  }) async {
    if (_tripId != null) {
      return const TrackingStartResult(TrackingStartOutcome.alreadyRunning);
    }

    try {
      final serviceResult = await _service.start(
        notificationTitle: notificationTitle,
        notificationBody: notificationBody,
        vanId: vanId,
      );
      if (serviceResult != ForegroundServiceStartResult.started) {
        _applyState(
          const TrackingEngineState(
            status: TrackingRunStatus.failed,
            error: 'foreground service start failed',
          ),
        );
        return const TrackingStartResult(
          TrackingStartOutcome.serviceStartFailed,
        );
      }
    } catch (error) {
      _applyState(
        TrackingEngineState(
          status: TrackingRunStatus.failed,
          error: error,
        ),
      );
      return const TrackingStartResult(TrackingStartOutcome.serviceStartFailed);
    }

    _tripId = tripId;
    _vanId = vanId;
    _lastWritten = null;
    _lastWriteAt = null;
    _latestFix = null;
    _latestVan = null;
    _intervalSec = _initialCheckInterval;
    _stopping = false;

    // F-D9 latch is trip-scoped: a fresh run starts unlatched; the ground
    // truth (`trips.mockLocationDetected`) is never unset by the app.
    _mockLocationLatched = false;

    // Trail buffer for THIS trip ('trail-<tripId>').
    final buffer = await _trailBufferFactory(tripId);
    _trailBuffer = buffer;

    // Keep the van doc, so a backend `offline` marking that lands mid-shift
    // can flip back to on_shift at the next successful write (Flow F).
    _vanDocSub = _vans.watchVan(vanId).listen((van) => _latestVan = van);

    // distanceFilter = minMoveM (PRD-2 F-D2 step 3). Fixes only update the
    // latest candidate; writes happen on the policy cadence below
    // (contract ruling: the interval is cadence-only). The intake point also
    // runs the F-D9 mock-location hook (see [_onFixIntake]).
    _fixSub = _position
        .fixes(distanceFilterM: minMoveM)
        .listen(_onFixIntake);

    // Cadence check + trail flush timers.
    _checkTimer = Timer.periodic(
      Duration(seconds: _intervalSec),
      (_) => unawaited(_guardedRunOnce()),
    );
    _flushTimer = Timer.periodic(
      Duration(seconds: _flushIntervalSec),
      (_) => unawaited(_guardedFlushTrail()),
    );

    _applyState(TrackingEngineState(
      status: TrackingRunStatus.running,
      tripId: tripId,
      vanId: vanId,
    ));
    return const TrackingStartResult(TrackingStartOutcome.started);
  }

  /// Resume path (PRD-2 F-D2 step 5): reattach to the open trip straight
  /// from the vans doc, never asking for the PIN again.
  ///
  /// Exactly the contract gate: `currentTripId != null && status == on_shift`.
  Future<TrackingResumeResult> startForActiveShift({
    required String vanId,
    required String notificationTitle,
    required String notificationBody,
  }) async {
    final van = await _vans.watchVan(vanId).first;

    final currentTripId = van?.currentTripId;
    final onShift = van?.status == VanStatus.onShift;

    if (!onShift || currentTripId == null) {
      return const TrackingResumeResult(
        outcome: TrackingResumeOutcome.notResumed,
      );
    }

    final result = await start(
      tripId: currentTripId,
      vanId: vanId,
      notificationTitle: notificationTitle,
      notificationBody: notificationBody,
    );

    return result.isStarted
        ? TrackingResumeResult(
            outcome: TrackingResumeOutcome.resumed,
            tripId: currentTripId,
          )
        : const TrackingResumeResult(outcome: TrackingResumeOutcome.notResumed);
  }

  /// Stops the run, cancelling timers/subscriptions and flushing the Trail
  /// buffer one last time (End Shift semantics; idempotent).
  Future<void> stop() => _applyStop();

  // ---------------------------------------------------------------------------
  // internals
  // ---------------------------------------------------------------------------

  /// Position intake (F-D2 step 3): every fix updates the write-policy
  /// candidate. F-D9 rides on the same point: a mocked fix latches
  /// `trips.mockLocationDetected = true` on the open trip, at most once per
  /// run (the local latch; the app NEVER writes `false` — the doc field is
  /// the latch the office and the banner read).
  void _onFixIntake(VanFix fix) {
    _latestFix = fix;
    if (!fix.isMocked || _mockLocationLatched || _tripId == null) return;
    _flagMockLocation();
  }

  /// Write the F-D9 latch through the repository (never direct Firestore).
  /// A failed write re-arms the local latch so the next mocked fix retries;
  /// offline connectivity alone cannot lose it, because (ruling 7) the repo
  /// write is the only mutation and it only ever sets `true`.
  void _flagMockLocation() {
    final tripId = _tripId;
    if (tripId == null) return;
    _mockLocationLatched = true;
    unawaited(
      _trips.setMockLocationDetected(tripId, detected: true).catchError(
            (Object error) {
              debugPrint('tracking: mock-location flag failed: $error');
              _mockLocationLatched = false; // retry on the next mock fix
            },
          ),
    );
  }

  Future<void> _applyStop() async {
    if (_tripId == null || _stopping) {
      _tripId = null;
      return;
    }
    _stopping = true;

    _checkTimer?.cancel();
    _checkTimer = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    await _fixSub?.cancel();
    _fixSub = null;
    await _vanDocSub?.cancel();
    _vanDocSub = null;

    final tripId = _tripId!;
    _tripId = null;
    _vanId = null;
    final buffer = _trailBuffer;

    await _flushTrailBufferFor(tripId, buffer);

    _trailBuffer = null;
    _lastWritten = null;
    _lastWriteAt = null;
    _latestFix = null;
    _latestVan = null;
    _intervalSec = _initialCheckInterval;
    _stopping = false;

    _applyState(TrackingEngineState(
      status: TrackingRunStatus.idle,
      tripId: tripId,
    ));
  }

  /// One cadence cycle: battery read → Write Policy → repository writes →
  /// buffer the accepted point. Exceptions are survivable (offline runs,
  /// battery API down): the next tick simply re-checks.
  Future<void> _guardedRunOnce() async {
    if (_tripId == null || _stopping) return;

    try {
      final fix = _latestFix;
      if (fix == null) return; // no fix yet; wait for the next tick

      final vanId = _vanId!;
      final battery = await _safeBatteryPct();
      final now = _clock();

      final decision = decideWrite(
        candidate: (lat: fix.lat, lng: fix.lng),
        lastWritten: _lastWritten,
        lastWriteTime: _lastWriteAt,
        batteryPct: battery,
        now: now,
      );

      // Interval switch (F-D8): the policy decides the NEXT cadence.
      if (decision.intervalUsed != _intervalSec) {
        _applyInterval(decision.intervalUsed);
      }

      if (!decision.shouldWrite) return;

      try {
        await _vans.updateLastLocation(
          vanId: vanId,
          lat: fix.lat,
          lng: fix.lng,
          speedKmph: fix.speedKmph,
        );
        if (battery != null) {
          await _vans.updateBatteryPct(vanId, battery);
        }
        _lastWritten = (lat: fix.lat, lng: fix.lng);
        _lastWriteAt = now;
        // Revive only counts after a LANDED write (F-D7 note).
        _reviveIfMarkedOffline(vanId);
      } catch (error) {
        // Dead zone (F-D7): queue the LATEST candidate; the queue's
        // latest-only slot never re-sends older-than-newest positions.
        final queue = _offlineWriteQueue;
        if (queue == null) rethrow;
        await queue.enqueueLastLocation(
          vanId: vanId,
          lat: fix.lat,
          lng: fix.lng,
          speedKmph: fix.speedKmph,
          recordedAt: fix.t,
        );
      } finally {
        // Trail point (0.13 Flow A): buffered EVEN when the write failed, so
        // a dead zone loses no trail points; order = accept order.
        await _trailBuffer?.add(
          GpsPoint(lat: fix.lat, lng: fix.lng, t: fix.t),
        );
      }
    } catch (error) {
      debugPrint('tracking: cadence check failed (will retry): $error');
    }
  }

  /// 0.13 Flow F driver side: a backend `vanOfflineWatch` may have marked
  /// the van offline while writes were silent; the very next successful
  /// write must set `status = on_shift` again.
  void _reviveIfMarkedOffline(String vanId) {
    if (_latestVan?.status != VanStatus.offline) return;
    unawaited(
      _vans.updateStatus(vanId, VanStatus.onShift).catchError(
            (Object error) =>
                debugPrint('tracking: status revive failed: $error'),
          ),
    );
  }

  Future<int?> _safeBatteryPct() async {
    try {
      return await _battery.readBatteryPct();
    } catch (error) {
      debugPrint('tracking: battery read failed: $error');
      return null; // unknown battery never slows the van (policy rule)
    }
  }

  void _applyInterval(int newIntervalSec) {
    _intervalSec = newIntervalSec;
    // The interval switch is exactly when the visible low-battery flag
    // changes (F-D8), so state is rebuilt on every decision.
    _state = TrackingEngineState(
      status: TrackingRunStatus.running,
      tripId: _tripId,
      vanId: _vanId,
      lowBatteryInterval: newIntervalSec == gpsIntervalLowBatterySec,
    );
    // Test cadence override: keep the fast tick (real cadences take minutes,
    // so re-arming would kill 1 s testing); state already reflects it.
    if (_initialCheckInterval != gpsIntervalSec) {
      _emitState();
      return;
    }
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(
      Duration(seconds: newIntervalSec),
      (_) => unawaited(_guardedRunOnce()),
    );
    _emitState();
  }

  /// One flush cycle: take ALL buffered points and append them to
  /// `trips.gpsTrail` in ONE batched write. On failure the batch goes back
  /// to the FRONT of the buffer, order preserved, so catch-up data keeps
  /// the trail in order on the next flush.
  Future<void> _guardedFlushTrail() async {
    if (_tripId == null || _stopping) return;
    try {
      await _flushTrailBuffer();
    } catch (error) {
      debugPrint('tracking: trail flush failed (will retry): $error');
    }
  }

  Future<void> _flushTrailBuffer() async {
    final buffer = _trailBuffer;
    final tripId = _tripId;
    if (buffer == null || tripId == null) return;
    await _flushTrailBufferFor(tripId, buffer);
  }

  Future<void> _flushTrailBufferFor(
    String tripId,
    TrailBuffer? buffer,
  ) async {
    if (buffer == null) return;

    final batch = await buffer.takeOldest();
    if (batch.isEmpty) return;

    try {
      await _trips.appendGpsTrail(tripId, batch);
    } catch (error) {
      debugPrint('DEBUG flushFor: append failed $error');
      await buffer.putBackOldest(batch);
      rethrow;
    }
  }

  void _applyState(TrackingEngineState state) {
    _state = state;
    _emitState();
  }

  void _emitState() {
    if (_changes.isClosed) return;
    _changes.add(_state);
  }
}
