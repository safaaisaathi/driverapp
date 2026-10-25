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
import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/theme/app_theme.dart';

import 'live_route_providers.dart';
import 'live_route_screen.dart';

/// Seeded van id for the demo (must exist in the emulator seed).
@visibleForTesting
const String devLiveRouteVanId = 'van-01';

/// `main()` for the debug demo (never used by main.dart): pins the demo van
/// id, fires the bootstrap WITHOUT awaiting it — `BootstrapController.run`
/// retries forever when Firebase is unreachable (degraded-only on a host
/// without Firebase plugins, e.g. the desktop preview), so awaiting would
/// postpone the UI forever — then shows D2.
Future<void> main() async {
  final container = ProviderContainer(
    overrides: [currentVanIdProvider.overrideWithValue(devLiveRouteVanId)],
  );
  unawaited(runBootstrap(container));
  runApp(UncontrolledProviderScope(
    container: container,
    child: const DevLiveRouteMaterialApp(),
  ));
}

/// Entry for `main.dart`-integration use (the integration ticket decides:
/// wire it in, or delete this file at ticket 14). Fire-and-forget bootstrap
/// for the same reason as [main].
Future<void> runDevLiveRouteApp(ProviderContainer container) async {
  unawaited(runBootstrap(container));
  runApp(UncontrolledProviderScope(
    container: container,
    child: const DevLiveRouteMaterialApp(),
  ));
}

class DevLiveRouteMaterialApp extends StatelessWidget {
  const DevLiveRouteMaterialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dev live route demo',
      theme: AppTheme.light(),
      // English default is a DEVELOPMENT-PHASE decision (grill round 1, Q7).
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const LiveRouteScreen(),
    );
  }
}
