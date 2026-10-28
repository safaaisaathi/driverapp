/// Post-start placeholder destination (F-D1 nav stack).
///
/// Ticket 05 (F-D2 background GPS + tracking engine) replaces this with
/// the real live-route screen (D2). It reads the native shift-active
/// state via [shiftControllerProvider] — that is the exact seam.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../data/shift_tracking_auto_start.dart';
import '../domain/shift_session.dart';

/// Minimal stand-in for D2. Shows the running shift's identity so the
/// demo driver can confirm the correct van/trip is live, and surfaces the
/// F-D2 auto-start outcome with recovery actions — a GPS master switch
/// that is off or a denied permission stage must never read as
/// "everything is fine" (device defect 2026-10-28).
class BasicRoutePlaceholder extends ConsumerWidget {
  const BasicRoutePlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(shiftControllerProvider);
    final autoStart = ref.watch(shiftTrackingAutoStartStatusProvider);
    final starter = ref.read(shiftTrackingAutoStarterProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.basicRouteTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingUnit * 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_shipping, size: 48),
              const SizedBox(height: AppTheme.spacingUnit * 2),
              Text(
                l10n.shiftStarted,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppTheme.spacingUnit),
              Text(
                session == null
                    ? ''
                    : '${session.vanId} · ${session.tripId} · ${session.routeId}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppTheme.spacingUnit * 2),
              if (autoStart == null ||
                  autoStart.kind == ShiftTrackingAutoStartKind.started)
                Text(
                  l10n.trackingPending,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .copyWith(color: AppTheme.colorTextMuted),
                )
              else ...[
                Text(
                  autoStart.kind == ShiftTrackingAutoStartKind.gpsOff
                      ? l10n.trackingGpsOff
                      : l10n.trackingPermissionDenied,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(color: AppTheme.colorTextMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingUnit * 2),
                if (autoStart.kind == ShiftTrackingAutoStartKind.gpsOff)
                  FilledButton(
                    key: const ValueKey('tracking-open-gps-settings'),
                    onPressed: () => unawaited(starter.openLocationSettings()),
                    child: Text(l10n.trackingOpenLocationSettings),
                  ),
                TextButton(
                  key: const ValueKey('tracking-start-retry'),
                  onPressed: session == null
                      ? null
                      : () => unawaited(
                          starter.startTrackingFor(
                            session,
                            notificationTitle: l10n.trackingNotificationTitle,
                            notificationBody: l10n.trackingNotificationBody,
                          ),
                        ),
                  child: Text(l10n.retry),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
