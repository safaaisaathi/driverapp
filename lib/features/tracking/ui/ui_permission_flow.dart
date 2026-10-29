/// UI-layer permission flow controller (F-D2 step 1).
///
/// Runs on the UI thread with a BuildContext to show the rationale
/// screens (DESIGN.md §4.19) before each system permission dialog.
/// The driver sees WHY the permission is needed, then taps "Allow" to
/// trigger the system dialog, or "Not now" to skip with a clear state.
library;

import 'package:flutter/material.dart';

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/features/tracking/ui/permission_prompt_screen.dart'
    show
        PermissionPromptStage,
        showPermissionPrompt;

import '../domain/permission_flow.dart'
    show
        PermissionFlowReport,
        PermissionApproval,
        TrackingPermissionStage;
import '../domain/permission_gateway.dart';

/// Runs the four permission stages with rationale screens.
///
/// Returns a [PermissionFlowReport] with the results. The flow stops
/// at the first denial (including "Not now" or GPS off), and the caller
/// can render the appropriate state.
class UIPermissionFlowController {
  /// Contract order (F-D2 step 1).
  static const List<TrackingPermissionStage> stages = [
    TrackingPermissionStage.locationWhileInUse,
    TrackingPermissionStage.locationBackground,
    TrackingPermissionStage.notifications,
    TrackingPermissionStage.batteryOptimization,
  ];

  final TrackingPermissionGateway _gateway;
  final BuildContext _context;

  const UIPermissionFlowController(this._gateway, this._context);

  Future<PermissionFlowReport> requestAll() async {
    final results = <TrackingPermissionStage, PermissionApproval>{};

    for (final stage in stages) {
      final approval = await _askWithRationale(stage);
      // debugPrint('tracking-flow-ui: $stage -> $approval');

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

  Future<PermissionApproval> _askWithRationale(TrackingPermissionStage stage) async {
    // Check if already granted (don't show rationale if already granted)
    final currentStatus = await _checkStatus(stage);
    if (currentStatus == PermissionApproval.granted) {
      return PermissionApproval.granted;
    }

    // Show rationale screen
    final uiStage = _toUIStage(stage);
    final allowed = await showPermissionPrompt(
      context: _context,
      stage: uiStage,
    );

    if (!allowed) {
      // Driver tapped "Not now" or dismissed
      return PermissionApproval.denied;
    }

    // Driver tapped "Allow" - now show system permission dialog via gateway
    return _callGatewayEnsure(stage);
  }

  Future<PermissionApproval> _checkStatus(TrackingPermissionStage stage) async {
    return switch (stage) {
      TrackingPermissionStage.locationWhileInUse =>
        _gateway.checkLocationWhileInUse(),
      TrackingPermissionStage.locationBackground =>
        _gateway.checkLocationBackground(),
      TrackingPermissionStage.notifications =>
        _gateway.checkNotifications(),
      TrackingPermissionStage.batteryOptimization =>
        _gateway.checkBatteryOptimization(),
    };
  }

  Future<PermissionApproval> _callGatewayEnsure(TrackingPermissionStage stage) async {
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

  PermissionPromptStage _toUIStage(TrackingPermissionStage stage) {
    return switch (stage) {
      TrackingPermissionStage.locationWhileInUse =>
        PermissionPromptStage.locationWhileInUse,
      TrackingPermissionStage.locationBackground =>
        PermissionPromptStage.locationBackground,
      TrackingPermissionStage.notifications =>
        PermissionPromptStage.notifications,
      TrackingPermissionStage.batteryOptimization =>
        PermissionPromptStage.batteryOptimization,
    };
  }
}