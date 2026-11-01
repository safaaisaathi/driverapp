/// The non-data states of the Live Route screen: loading, error (retry),
/// empty (route missing / no wards) — spec user story 24: the app is boring
/// and predictable on every screen.
///
/// DESIGN-driver-app.md §4.16, §7: Skeleton for loading, neutral icon in a
/// `brandSoft` circle for empty (mascot-free, CL-D15), full-screen error
/// with retry. All via tokens (CL-01 to CL-05).
library;

import 'package:flutter/material.dart';

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/theme/app_colors.dart';
import 'package:driverapp/core/theme/app_text.dart';
import 'package:driverapp/core/theme/app_tokens.dart';
import 'package:driverapp/core/widgets/skeleton.dart';

import '../domain/live_route_state.dart';

class LiveRouteLoadingView extends StatelessWidget {
  const LiveRouteLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('liveRoute.loading'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpace.lg,
        children: [
          // Skeleton matching the live route layout (CL-06: 32dp spinner max)
          const SkeletonMapPlaceholder(),
          const SizedBox(height: AppSpace.xl),
          // Skeleton for the sheet content
          SkeletonContourCard(width: double.infinity, height: 80),
          const SizedBox(height: AppSpace.cardGap),
          SkeletonBigActionButton(),
          const SizedBox(height: AppSpace.cardGap),
          ...List.generate(
            3,
            (i) => const SkeletonWardRow(),
          ),
        ],
      ),
    );
  }
}

class SkeletonMapPlaceholder extends StatelessWidget {
  const SkeletonMapPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 200,
      height: 120,
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}

class SkeletonContourCard extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonContourCard({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c.brandMid.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Center(
        child: SkeletonBox(width: width * 0.6, height: 24, radius: 12),
      ),
    );
  }
}

class SkeletonBigActionButton extends StatelessWidget {
  const SkeletonBigActionButton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: AppSize.bigAction,
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Center(
        child: SkeletonBox(width: 120, height: 20, radius: 10),
      ),
    );
  }
}

class SkeletonWardRow extends StatelessWidget {
  const SkeletonWardRow({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        spacing: AppSpace.md,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.surface,
            ),
          ),
          Expanded(child: SkeletonBox(width: 150, height: 16)),
          SkeletonBox(width: 60, height: 24),
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
    final c = context.colors;
    return Center(
      key: const Key('liveRoute.error'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpace.lg,
          children: [
            Icon(Icons.error_outline, size: 48, color: c.statusEscalated.fill),
            Text(
              l10n.error,
              textAlign: TextAlign.center,
              style: context.text.body.copyWith(color: c.textPrimary),
            ),
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
    final c = context.colors;
    final message = reason == LiveRouteEmptyReason.routeMissing
        ? l10n.routeMissingMessage
        : l10n.routeEmptyMessage;
    return Center(
      key: const Key('liveRoute.empty'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpace.lg,
          children: [
            // Neutral icon in a `brandSoft` circle for empty state
            // (DESIGN-driver-app.md §4.16, CL-D15, removed-T8).
            Container(
              width: AppSize.permissionIconCircle,
              height: AppSize.permissionIconCircle,
              decoration: BoxDecoration(
                color: c.brandSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_outlined,
                size: AppSize.icon * 2,
                color: c.brand,
              ),
            ),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.body.copyWith(color: c.textMuted),
            ),
            if (reason == LiveRouteEmptyReason.routeMissing)
              FilledButton(
                key: const Key('liveRoute.emptyRetry'),
                onPressed: () {
                  // Trigger a retry through the provider
                  // The parent will handle the retry
                },
                child: Text(l10n.retry),
              ),
          ],
        ),
      ),
    );
  }
}
