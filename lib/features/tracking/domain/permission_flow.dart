/// The permission flow controller (F-D2 step 1): asks the four stages in
/// contract order, each with ONE simple localized explanation (the claim
/// text lives in the l10n arb files, keyed per stage — no hardcoded copy).
///
/// Denials stop the flow early with a clearly reported failed stage; the
/// caller shows the localized message and the app stays usable
/// (never a crash).
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'permission_gateway.dart';

/// Outcome of walking the four stages.
class PermissionFlowReport {
  /// Stage → approval, in the order the stages were asked.
  final Map<TrackingPermissionStage, PermissionApproval> results;

  /// The stage that was denied, if any; `null` when all stages were granted
  /// (or when no stage was even asked — see [noStagesAsked]).
  final TrackingPermissionStage? failedStage;

  const PermissionFlowReport({required this.results, this.failedStage});

  static const PermissionFlowReport whenNothingAsked =
      PermissionFlowReport(results: {});

  bool get allGranted => failedStage == null;

  bool get noStagesAsked => results.isEmpty;

  /// The stages the flow actually asked, in order.
  List<TrackingPermissionStage> get askedStages =>
      results.keys.toList(growable: false);
}

/// Asks [TrackingPermissionGateway] stages in contract order and stops at
/// the first denial.
class PermissionFlowController {
  /// Contract order (F-D2 step 1).
  static const List<TrackingPermissionStage> stages = [
    TrackingPermissionStage.locationWhileInUse,
    TrackingPermissionStage.locationBackground,
    TrackingPermissionStage.notifications,
    TrackingPermissionStage.batteryOptimization,
  ];

  final TrackingPermissionGateway _gateway;

  const PermissionFlowController(this._gateway);

  Future<PermissionFlowReport> requestAll() async {
    final results = <TrackingPermissionStage, PermissionApproval>{};

    for (final stage in stages) {
      final approval = await _ask(stage);
      debugPrint('tracking-flow: $stage -> $approval');

      // A stage may report GPS-off without being "denied by the user"; it
      // still blocks tracking, so treat it as the failed stage.
      if (approval != PermissionApproval.granted) {
        results[stage] = approval;
        return PermissionFlowReport(
          results: results,
          failedStage: stage,
        );
      }
      results[stage] = approval;
    }

    return PermissionFlowReport(results: results);
  }

  Future<PermissionApproval> _ask(TrackingPermissionStage stage) {
    return switch (stage) {
      TrackingPermissionStage.locationWhileInUse =>
        _gateway.ensureLocationWhileInUse(),
      TrackingPermissionStage.locationBackground =>
        _gateway.ensureLocationBackground(),
      TrackingPermissionStage.notifications =>
        _gateway.ensureNotifications(),
      TrackingPermissionStage.batteryOptimization =>
        _gateway.ensureBatteryOptimizationExemption(),
    };
  }
}
