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
/// 6. Depot auto-end (ruling #29): while a fix exists, the engine feeds the
///    van position to [DepotDwellTracker]. Three continuous hours inside
///    500 m of the admin-set `vans.depot` runs the SAME end-shift write set
///    as D5 (shared core), stops the run, and reports the ended trip id to
///    the app layer. A failed write keeps the shift open and retries after
///    [depotAutoEndRetryDelay].
///
/// Platform channels (location stream, battery, foreground service, trail
/// box) are injectable seams: small interfaces in this folder, real
/// implementations under `data/` (spec: tests mock seams, never a device).
library;

import 'dart:async';

import 'package:flutter/foundation.dart'
    show debugPrint, visibleForTesting;
import 'package:driverapp/core/config/constants.dart';
import 'package:driverapp/core/config/firebase_bootstrap.dart'
    show MessagingGateway;
import 'package:driverapp/core/contract/shift_gateway.dart';
import 'package:driverapp/core/contract/tracking_gateway.dart';
import 'package:driverapp/core/domain/end_shift_writes.dart';
import 'package:driverapp/core/domain/geo_point.dart';
import 'package:driverapp/core/domain/write_policy.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repositories.dart';

import '../offline/offline_write_queue.dart';
import 'battery_source.dart';
import 'depot_dwell.dart';
import 'foreground_service.dart';
import 'position_fix.dart';
import 'position_source.dart';
import 'trail_buffer.dart';

/// Seconds between trail flushes (PRD-2 0.13 Flow A step 4).
const int trailFlushIntervalSec = 30;

/// After a failed depot auto-end write (offline, rules), the next attempt
/// waits this long; the dwell latch stays over the limit meanwhile.
const Duration depotAutoEndRetryDelay = Duration(minutes: 5);

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
    /// CHG-0003: the shift callables. The depot auto-end (ruling #29) closes
    /// the trip through `endShift`, the same callable D5 uses.
    required ShiftGateway shiftGateway,
    /// CHG-0017: the tracking callables. A mocked fix latches locally at
    /// once and is persisted through `flagMockLocation`; a failed call
    /// retries on the regular cadence.
    required TrackingGateway trackingGateway,
    /// F-D9: mirrors the local mock latch into the app layer so the banner
    /// does not wait for the network. Called with true on the first mocked
    /// fix and false when a run starts or ends.
    void Function(bool latched)? onMockLocationLatchChanged,
    /// Ruling #29: called with the ended trip id after the depot rule
    /// auto-ends a shift, so the app layer can clear its shift session and
    /// show the notice.
    void Function(String tripId)? onShiftAutoEnded,
    /// The shift topic seam (`van_{vanId}`): the depot auto-end runs the
    /// SAME cleanup as D5, so no path leaves the install subscribed.
    MessagingGateway? messaging,
    String Function(String vanId)? vanTopicOf,
  })  : _vans = vansRepository,
        _trips = tripsRepository,
        _gateway = shiftGateway,
        _trackingGateway = trackingGateway, // ignore: prefer_initializing_formals
        _position = positionSource,
        _battery = batterySource,
        _service = serviceHandle,
        _trailBufferFactory = trailBufferFactory, // ignore: prefer_initializing_formals
        _clock = clock ?? DateTime.now,
        _initialCheckInterval = checkIntervalSec ?? gpsIntervalSec,
        _flushIntervalSec = flushIntervalSec ?? trailFlushIntervalSec,
        _offlineWriteQueue = offlineWriteQueue, // ignore: prefer_initializing_formals
        _onMockLocationLatchChanged = onMockLocationLatchChanged, // ignore: prefer_initializing_formals
        _onShiftAutoEnded = onShiftAutoEnded, // ignore: prefer_initializing_formals
        _messaging = messaging, // ignore: prefer_initializing_formals
        _vanTopicOf = vanTopicOf; // ignore: prefer_initializing_formals

  final VansRepository _vans;
  final TripsRepository _trips;
  final ShiftGateway _gateway;
  final TrackingGateway _trackingGateway;
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

  /// F-D9: mirrors the local latch into the app layer (banner).
  final void Function(bool latched)? _onMockLocationLatchChanged;

  /// Ruling #29: app-layer hook that clears the shift session.
  final void Function(String tripId)? _onShiftAutoEnded;

  /// Topic cleanup seam, used by the depot auto-end only when both are set.
  final MessagingGateway? _messaging;
  final String Function(String vanId)? _vanTopicOf;

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

  /// One flush write at a time: a slow uplink can outlast the 30 s tick, and
  /// a second overlapping batch would race the first out of order.
  bool _flushInFlight = false;
  int _intervalSec = gpsIntervalSec;
  GeoPoint? _lastWritten;
  DateTime? _lastWriteAt;
  VanFix? _latestFix;
  Van? _latestVan;
  bool _stopping = false;

  /// F-D9 local latch: drives the banner the moment a mock fix lands. NOT the
  /// ground truth — `trips.mockLocationDetected` in the trip doc is
  /// (kill/restart safe, never unset by the app). The durable write goes
  /// through `flagMockLocation` (CHG-0017).
  bool _mockLocationLatched = false;

  /// The trip whose `flagMockLocation` call already succeeded, so the
  /// cadence retry stops. Null until a call lands.
  String? _mockLocationPersistedTripId;

  /// One callable attempt at a time.
  bool _mockFlagInFlight = false;

  /// Test-only view of the F-D9 local latch: true after the first mocked fix
  /// of this run. The trip doc (`trips.mockLocationDetected`) is the real
  /// ground truth, written by the server-side callable (CHG-0017).
  @visibleForTesting
  bool get mockLocationLatched => _mockLocationLatched;

  /// Ruling #29: depot dwell state for the current run, `null` until the van
  /// doc carries a depot.
  DepotDwellTracker? _depotDwell;

  bool _autoEnding = false;

  /// Set after a failed auto-end write so an offline phone retries later
  /// instead of hammering Firestore every tick.
  DateTime? _autoEndRetryAfter;

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

    // Ruling #29: a fresh run starts with no dwell clock; the van doc (read
    // right below) brings the depot.
    _depotDwell = null;
    _autoEnding = false;
    _autoEndRetryAfter = null;

    // F-D9 latch is trip-scoped: a fresh run starts unlatched; the ground
    // truth (`trips.mockLocationDetected`) is never unset by the app.
    _setMockLocationLatch(false);
    _mockLocationPersistedTripId = null;

    // Trail buffer for THIS trip ('trail-<tripId>').
    final buffer = await _trailBufferFactory(tripId);
    _trailBuffer = buffer;

    // Keep the van doc, so a backend `offline` marking that lands mid-shift
    // can flip back to on_shift at the next successful write (Flow F). The
    // same stream carries the admin-set depot for the auto-end rule (#29).
    _vanDocSub = _vans.watchVan(vanId).listen(_onVanDoc);

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

  /// Keeps the van value fresh (Flow F revive) and builds the depot dwell
  /// tracker as soon as the admin-set `vans.depot` arrives (ruling #29). A
  /// mid-shift depot move restarts the clock on the new centre.
  void _onVanDoc(Van? van) {
    _latestVan = van;
    final depot = van?.depot;
    if (depot == null) return;
    final tracker = _depotDwell;
    if (tracker == null || tracker.depot != depot) {
      _depotDwell = DepotDwellTracker(depot: depot);
    }
  }

  /// Position intake (F-D2 step 3): every fix updates the write-policy
  /// candidate. F-D9 rides on the same point: a mocked fix latches the local
  /// banner at once and asks the server to set the durable latch
  /// (`flagMockLocation`, CHG-0017).
  void _onFixIntake(VanFix fix) {
    _latestFix = fix;
    if (!fix.isMocked || _mockLocationLatched || _tripId == null) return;
    _setMockLocationLatch(true);
    unawaited(_persistMockLocation(_tripId!));
  }

  /// Sets the local latch and mirrors it into the app layer so the banner
  /// shows without waiting for the network.
  void _setMockLocationLatch(bool value) {
    if (_mockLocationLatched == value) return;
    _mockLocationLatched = value;
    _onMockLocationLatchChanged?.call(value);
  }

  /// `flagMockLocation({tripId})` (CHG-0017). The callable is idempotent, so
  /// a retry after a dropped response is safe. A failure is logged and left
  /// for the cadence retry; the local banner is already up.
  Future<void> _persistMockLocation(String tripId) async {
    if (_mockFlagInFlight) return;
    _mockFlagInFlight = true;
    try {
      await _trackingGateway.flagMockLocation(tripId);
      _mockLocationPersistedTripId = tripId;
    } catch (error) {
      debugPrint('tracking: flagMockLocation failed (will retry): $error');
    } finally {
      _mockFlagInFlight = false;
    }
  }

  /// Retries the durable latch on the regular cadence, so a reconnect lands
  /// it even when no new fix arrives.
  void _retryMockLocationIfPending() {
    final tripId = _tripId;
    if (!_mockLocationLatched || tripId == null) return;
    if (_mockLocationPersistedTripId == tripId) return;
    unawaited(_persistMockLocation(tripId));
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

    // The foreground service owns the persistent "Tracking active"
    // notification: without this call it outlives End Shift (PRD-2 §3 +
    // F-D5 step 4 "stop the service"), leaving a stale notification until
    // the process dies. Best effort: a platform failure must not block the
    // trail flush below.
    try {
      await _service.stop();
    } catch (error) {
      debugPrint('tracking: foreground service stop failed: $error');
    }

    final tripId = _tripId!;
    _tripId = null;
    _vanId = null;
    final buffer = _trailBuffer;

    await _flushTrailBufferFor(tripId, buffer);
    // End Shift drains the WHOLE buffer, one measured batch at a time: a
    // final flush that wrote everything at once is the write that stalled
    // on a slow uplink (issue #13).
    while ((buffer?.pendingCount ?? 0) > 0) {
      await _flushTrailBufferFor(tripId, buffer);
    }

    _trailBuffer = null;
    _lastWritten = null;
    _lastWriteAt = null;
    _latestFix = null;
    _latestVan = null;
    _intervalSec = _initialCheckInterval;
    _stopping = false;
    _depotDwell = null;
    _autoEndRetryAfter = null;
    _setMockLocationLatch(false);
    _mockLocationPersistedTripId = null;

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

    // CHG-0017: a durable mock flag that failed offline retries here, so a
    // reconnect lands it without waiting for another mocked fix.
    _retryMockLocationIfPending();

    try {
      final fix = _latestFix;
      if (fix == null) return; // no fix yet; wait for the next tick

      final vanId = _vanId!;
      final battery = await _safeBatteryPct();
      final now = _clock();

      // Ruling #29: depot dwell is evaluated on every cadence, independent of
      // the write policy (a parked van may legitimately skip writes).
      final dwell = _depotDwell;
      if (dwell != null && dwell.update((lat: fix.lat, lng: fix.lng), now)) {
        unawaited(_autoEndShift(now));
        return; // the auto-end owns the run from here
      }

      final decision = decideWrite(
        candidate: (lat: fix.lat, lng: fix.lng),
        lastWritten: _lastWritten,
        lastWriteTime: _lastWriteAt,
        batteryPct: battery,
        now: now,
      );
      const trackDebug = true;
      if (trackDebug) {
        final moveM = _lastWritten == null
            ? -1.0
            : (fix.lat - _lastWritten!.lat).abs() *
                111320 +
                (fix.lng - _lastWritten!.lng).abs() * 111320;
        debugPrint(
          'tracking: cycle t=${now.toIso8601String()} '
          'shouldWrite=${decision.shouldWrite} '
          'intervalUsed=${decision.intervalUsed} '
          'moveM=${moveM.toStringAsFixed(1)} '
          'pend=${_trailBuffer == null ? -1 : _trailBuffer!.pendingCount}',
        );
      }

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

  /// Ruling #29: the van has been parked at the depot for 3 hours. Close the
  /// SAME shift as D5 (shared core, the `endShift` callable), stop the
  /// engine, then tell the app layer to clear its session. A failed call
  /// keeps the trip open and retries after [depotAutoEndRetryDelay] (an
  /// offline phone must not lose the shift, and must not spin either).
  Future<void> _autoEndShift(DateTime now) async {
    final tripId = _tripId;
    if (tripId == null || _autoEnding) return;
    final retryAfter = _autoEndRetryAfter;
    if (retryAfter != null && now.isBefore(retryAfter)) return;

    _autoEnding = true;
    try {
      final vanId = _vanId;
      final topicOf = _vanTopicOf;
      await writeEndShift(
        gateway: _gateway,
        tripId: tripId,
        stopTracking: stop,
        messaging: _messaging,
        vanTopic: vanId != null && topicOf != null ? topicOf(vanId) : null,
      );
      debugPrint('tracking: depot auto-end wrote the end-shift set ($tripId)');
      _onShiftAutoEnded?.call(tripId);
    } catch (error) {
      _autoEndRetryAfter = now.add(depotAutoEndRetryDelay);
      debugPrint(
        'tracking: depot auto-end failed, retry in '
        '${depotAutoEndRetryDelay.inMinutes} min: $error',
      );
    } finally {
      _autoEnding = false;
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
    if (_tripId == null || _stopping || _flushInFlight) return;
    _flushInFlight = true;
    try {
      await _flushTrailBuffer();
    } catch (error) {
      debugPrint('tracking: trail flush failed (will retry): $error');
    } finally {
      _flushInFlight = false;
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

    final batch = await buffer.takeOldest(limit: maxTrailBatchPoints);
    if (batch.isEmpty) return;
    debugPrint('tracking: flush ${batch.length} points');

    try {
      await _trips.appendGpsTrail(tripId, batch);
      debugPrint('tracking: flush OK (${batch.length})');
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
