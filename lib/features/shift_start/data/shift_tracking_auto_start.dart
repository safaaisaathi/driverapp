/// F-D2 auto-start seam (wiring defect found on device 2026-10-28).
///
/// PRD (0.13 / F-D2): the tracking engine turns on the moment D1's flow
/// produces an on-shift session — fresh start or resume relaunch alike —
/// after the four-stage permission flow in contract order. Until this seam
/// existed nothing in the REAL flow called the engine (only the dev screen
/// did), so a started shift displayed "Van tracking will start
/// automatically." while the engine stayed idle: no OS location permission
/// was ever requested and `vans.lastLocation` never advanced.
///
/// The widget layer fires this after D1 activates the session. The report
/// is NEVER swallowed silently: the outcome lands in
/// [shiftTrackingAutoStartStatusProvider], which the active-shift screen
/// renders as a localized state with recovery actions (open location
/// settings / retry) — observed defect: the flow short-circuits at the GPS
/// master switch with zero prompts, and "nothing happens" is not a state
/// a driver can understand.
///
/// Widget tests override [shiftTrackingAutoStarterProvider] with a
/// recording fake — platform channels are never reached (spec seam 1).
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../tracking/offline/offline_providers.dart';
import '../../tracking/tracking_providers.dart';
import '../domain/shift_session.dart';

/// The outcome of one auto-start attempt (what the driver sees).
enum ShiftTrackingAutoStartKind { started, denied, gpsOff }

final class ShiftTrackingAutoStart {
  const ShiftTrackingAutoStart(this.kind);

  final ShiftTrackingAutoStartKind kind;
}

/// The D1 → F-D2 hand-over contract: start (or restart) the tracking
/// engine for this session's trip, and open location settings when the
/// GPS master switch stands between the flow and its prompts.
abstract interface class ShiftTrackingAutoStarter {
  Future<ShiftTrackingAutoStart> startTrackingFor(
    ShiftSession session, {
    required String notificationTitle,
    required String notificationBody,
  });

  /// System path to the location (GPS) settings — the [gpsOff] recovery.
  Future<void> openLocationSettings();
}

/// Real starter: contract-order permission flow, engine start, surfaced
/// outcome.
final class TrackingAutoStarter implements ShiftTrackingAutoStarter {
  const TrackingAutoStarter(this._ref);

  final Ref _ref;

  @override
  Future<ShiftTrackingAutoStart> startTrackingFor(
    ShiftSession session, {
    required String notificationTitle,
    required String notificationBody,
  }) async {
    // F-D7: the offline sync service drains the ACTIVE trip's Trail buffer on
    // every reconnect, but nothing in the real flow ever called `attachTrip`,
    // so a shift's catch-up trail never synced (PRD F-D7 + §4 AC#4). Attach
    // before the permission flow: the trip exists the moment the session
    // does, even if the driver denies a permission now.
    _ref.read(offlineSyncServiceProvider).attachTrip(session.tripId);

    final report = await PermissionFlowController(
      _ref.read(trackingPermissionGatewayProvider),
    ).requestAll();

    final started = report.allGranted
        ? await _ref
            .read(trackingEngineProvider)
            .start(
              tripId: session.tripId,
              vanId: session.vanId,
              notificationTitle: notificationTitle,
              notificationBody: notificationBody,
            )
            .then((result) {
              debugPrint('tracking-flow: engine.start -> ${result.outcome}');
              return result.isStarted;
            })
        : false;

    final gpsOff = report.results.values
        .any((approval) => approval == PermissionApproval.gpsOff);

    // The screen renders this — silence is never a state (defect note).
    final outcome = ShiftTrackingAutoStart(
      started
          ? ShiftTrackingAutoStartKind.started
          : gpsOff
              ? ShiftTrackingAutoStartKind.gpsOff
              : ShiftTrackingAutoStartKind.denied,
    );
    _ref
        .read(shiftTrackingAutoStartStatusProvider.notifier)
        .set(outcome);
    return outcome;
  }

  @override
  Future<void> openLocationSettings() =>
      Geolocator.openLocationSettings();
}

/// Wires the real starter; tests override with a recording fake.
final Provider<ShiftTrackingAutoStarter> shiftTrackingAutoStarterProvider =
    Provider<ShiftTrackingAutoStarter>((ref) => TrackingAutoStarter(ref));

/// Drives the active-shift screen's tracking state banner. Set by every
/// [ShiftTrackingAutoStarter.startTrackingFor]; `null` = never attempted
/// (pre-D1) or a fresh `started` run.
final NotifierProvider<ShiftTrackingAutoStartStatusController,
        ShiftTrackingAutoStart?> shiftTrackingAutoStartStatusProvider =
    NotifierProvider<ShiftTrackingAutoStartStatusController,
        ShiftTrackingAutoStart?>(
  ShiftTrackingAutoStartStatusController.new,
);

/// Not `final`: widget tests extend it to force a banner state without
/// Geolocator (issue #23's 360 dp layout test).
class ShiftTrackingAutoStartStatusController
    extends Notifier<ShiftTrackingAutoStart?> {
  @override
  ShiftTrackingAutoStart? build() => null;

  void set(ShiftTrackingAutoStart? outcome) => state = outcome;
}
