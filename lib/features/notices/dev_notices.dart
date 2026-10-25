/// DEBUG ENTRYPOINT — D3 Notices inbox demo (ticket 09), NOT referenced
/// by `main.dart`; the integration ticket wires this in (or deletes it)
/// in the pattern of `dev_tracking.dart` (dev entrypoints fold out at
/// ticket 14).
///
/// To run: point `main.dart` at [runDevNoticesApp] with the Firebase
/// emulators up and seeded — `routes/route-01` (wardIds in visiting order)
/// and `vans/van-01` (routeId route-01), plus `notices` docs shaped per
/// 0.7: `targetType` `van` with `targetId` `van-01`, `ward` with `targetId`
/// inside route-01's wards, or `all` (no addressee). The demo activates
/// its OWN shift session (van + route context for D3; D1 is not part of
/// the demo) and reuses the real repository spine.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/firebase_bootstrap.dart';
import '../../core/domain/ist_clock.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../shift_start/domain/shift_session.dart';
import 'ui/notices_screen.dart';

/// Seeded van id for the demo (must exist in the emulator seed).
@visibleForTesting
const String devNoticesVanId = 'van-01';

/// Seeded route id for the demo (must exist in the emulator seed).
@visibleForTesting
const String devNoticesRouteId = 'route-01';

/// `main()`-like entrypoint for the debug demo (never used by main.dart).
/// Boots Firebase/emulators FIRST (ticket 02), activates the dev shift
/// session, then shows D3 with the real repository spine.
Future<void> runDevNoticesApp() async {
  final container = ProviderContainer();
  await runBootstrap(container); // degrades gracefully when emulators down
  final now = DateTime.now();
  container.read(shiftControllerProvider.notifier).activate(
        ShiftSession(
          vanId: devNoticesVanId,
          tripId: 'dev-trip-1',
          routeId: devNoticesRouteId,
          startedAt: now,
          date: utcStartOfIstDay(now),
        ),
      );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DevNoticesApp(),
    ),
  );
}

class DevNoticesApp extends StatelessWidget {
  const DevNoticesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dev notices demo',
      theme: AppTheme.light(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const NoticesScreen(),
    );
  }
}
