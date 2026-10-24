/// Post-start placeholder destination (F-D1 nav stack).
///
/// Ticket 05 (F-D2 background GPS + tracking engine) replaces this with
/// the real live-route screen (D2). It reads the native shift-active
/// state via [shiftControllerProvider] — that is the exact seam.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/shift_session.dart';

/// Minimal stand-in for D2. Shows the running shift's identity so the
/// demo driver can confirm the correct van/trip is live.
class BasicRoutePlaceholder extends ConsumerWidget {
  const BasicRoutePlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(shiftControllerProvider);
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
              Text(
                l10n.trackingPending,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall!
                    .copyWith(color: AppTheme.colorTextMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
