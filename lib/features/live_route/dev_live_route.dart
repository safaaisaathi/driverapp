/// DEBUG ENTRYPOINT — Live Route demo WITHOUT ticket 04's D1 dependency
/// (ticket 06 deliverable: "removed/flagged at integration").
///
/// NOT referenced by `main.dart`; the integration ticket wires this in (or
/// deletes it) once D1's PIN + Start Shift flow exists. To run the demo
/// locally, temporarily point `main.dart` at [runDevLiveRouteApp].
///
/// Mirrors `lib/features/tracking/dev_tracking.dart`: boots
/// Firebase/emulators FIRST (degrading gracefully when they are down), then
/// shows the D2 screen against the seeded van `van-01`. The real van id
/// comes from D1 at integration (`currentVanIdProvider`).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driverapp/core/config/firebase_bootstrap.dart';
import 'package:driverapp/core/domain/ist_clock.dart';
import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/l10n/locale_controller.dart';
import 'package:driverapp/core/repositories/repository_providers.dart';
import 'package:driverapp/core/theme/app_theme.dart';
import 'package:driverapp/features/shift_start/domain/shift_session.dart';

import 'dev/desktop_demo_seed.dart';
import 'live_route_providers.dart';
import 'live_route_screen.dart';

/// Seeded van id for the demo (must exist in the emulator seed).
@visibleForTesting
const String devLiveRouteVanId = devSeedVanId;

/// `main()` for the debug demo (never used by main.dart): pins the demo
/// van id, wires the DESKTOP seed doubles (no Firebase plugins on a Linux
/// desktop host — the Firestore spine degrades every flow to its error
/// state there), fires the bootstrap WITHOUT awaiting it —
/// `BootstrapController.run` retries forever when Firebase is unreachable,
/// so awaiting would postpone the UI forever — then shows D2 with D3's
/// unread badge live.
Future<void> main() async {
  final seed = DevDesktopSeed();
  final container = ProviderContainer(
    overrides: [
      currentVanIdProvider.overrideWithValue(devLiveRouteVanId),
      vansRepositoryProvider.overrideWithValue(seed.vans),
      tripsRepositoryProvider.overrideWithValue(seed.trips),
      routesRepositoryProvider.overrideWithValue(seed.routes),
      wardsRepositoryProvider.overrideWithValue(seed.wards),
      noticesRepositoryProvider.overrideWithValue(seed.notices),
      complaintsRepositoryProvider.overrideWithValue(seed.complaints),
    ],
  );
  // D3 context: the inbox + badge read the shift session (van + route).
  // Same self-serve activation as `dev_notices.dart`.
  final now = DateTime.now();
  container
      .read(shiftControllerProvider.notifier)
      .activate(
        ShiftSession(
          vanId: devLiveRouteVanId,
          tripId: devSeedTripId,
          routeId: devSeedRouteId,
          startedAt: now,
          date: utcStartOfIstDay(now),
        ),
      );
  unawaited(runBootstrap(container));
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DevLiveRouteMaterialApp(),
    ),
  );
}

/// Entry for `main.dart`-integration use (the integration ticket decides:
/// wire it in, or delete this file at ticket 14). Fire-and-forget bootstrap
/// for the same reason as [main].
Future<void> runDevLiveRouteApp(ProviderContainer container) async {
  unawaited(runBootstrap(container));
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DevLiveRouteMaterialApp(),
    ),
  );
}

class DevLiveRouteMaterialApp extends ConsumerWidget {
  const DevLiveRouteMaterialApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Dev live route demo',
      theme: buildTheme(Brightness.light),
      // English default is a DEVELOPMENT-PHASE decision (grill round 1, Q7).
      // Bound to the locale controller so the GLASS BAR toggle flips the
      // WHOLE app live (F-D10).
      locale: ref.watch(localeControllerProvider) ?? const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const LiveRouteScreen(),
    );
  }
}
