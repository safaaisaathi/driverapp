/// The non-data states of the Live Route screen: loading, error (retry),
/// empty (route missing / no wards) — spec user story 24: the app is boring
/// and predictable on every screen.
library;

import 'package:flutter/material.dart';

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/theme/app_theme.dart';

import '../domain/live_route_state.dart';
class LiveRouteLoadingView extends StatelessWidget {
  const LiveRouteLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      key: const Key('liveRoute.loading'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          const CircularProgressIndicator(),
          Text(l10n.loading, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class LiveRouteErrorView extends StatelessWidget {
  final void Function() onRetry;

  const LiveRouteErrorView({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      key: const Key('liveRoute.error'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppTheme.colorStatusEscalated),
            Text(l10n.error, textAlign: TextAlign.center),
            FilledButton(
              key: const Key('liveRoute.retry'),
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class LiveRouteEmptyView extends StatelessWidget {
  final LiveRouteEmptyReason reason;

  const LiveRouteEmptyView({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = reason == LiveRouteEmptyReason.routeMissing
        ? l10n.routeMissingMessage
        : l10n.routeEmptyMessage;
    return Center(
      key: const Key('liveRoute.empty'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            const Icon(Icons.route, size: 48, color: AppTheme.colorTextMuted),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
