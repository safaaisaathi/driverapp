/// DEVELOPMENT-ONLY desktop entrypoint — DevFlowPreviewApp.
///
/// Runs the REAL launching flow (Splash → Welcome → Start Duty → D1)
/// against the `DevDesktopSeed` doubles, because Linux/Windows desktop
/// hosts have no Firebase plugins: with the real bootstrap the D1 data
/// spine degrades to its error state there and nothing visual below the
/// launching screens can be demoed. This is the same trick
/// `dev_live_route.dart` uses for D2, extended to the full D1 flow.
///
/// NOT referenced by `main.dart`; run with:
///   `flutter run -t lib/dev_flow_preview.dart -d linux`
///
/// Deleted at ticket 14 together with the other dev entrypoints
/// (GLOSSARY bag). The doubles implement `core/repositories` interfaces
/// verbatim (dev/demo doubles, not schema).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/firebase_bootstrap.dart';
import 'core/domain/ist_clock.dart';
import 'core/l10n/app_localizations.dart';
import 'core/l10n/locale_controller.dart';
import 'core/repositories/repository_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'features/live_route/dev/desktop_demo_seed.dart';
import 'features/launching/splash_screen.dart';
import 'features/shift_start/data/verify_driver_pin.dart';
import 'features/shift_start/domain/shift_session.dart';

/// The dev seed contract (from `desktop_demo_seed.dart`): the demo van /
/// route / trip trio the doubles derive everything from.
const String devPreviewVanId = devSeedVanId;

/// Desktop PIN double: any 4 digits verify, except `0000` which replays
/// the wrong-PIN state so the red error treatment is checkable at the
/// table (PRD seed demo; real verify is the `verifyDriverPin` callable).
class DevPinVerifier implements DriverPinVerifier {
  const DevPinVerifier();

  @override
  Future<String> verifyPin({
    required String vanId,
    required String pin,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (pin == '0000') {
      throw const DriverPinException(DriverPinFailureKind.wrongPin);
    }
    return 'dev-token-$vanId';
  }
}

/// Desktop auth double: the flow only needs a uid to bind the session to.
class DevAuthGateway implements DriverAuthGateway {
  const DevAuthGateway();

  @override
  Future<String> signInWithCustomToken(String token) async => 'dev-driver-uid';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final seed = DevDesktopSeed();
  final now = DateTime.now();
  final container = ProviderContainer(
    overrides: [
      vansRepositoryProvider.overrideWithValue(seed.vans),
      tripsRepositoryProvider.overrideWithValue(seed.trips),
      routesRepositoryProvider.overrideWithValue(seed.routes),
      wardsRepositoryProvider.overrideWithValue(seed.wards),
      noticesRepositoryProvider.overrideWithValue(seed.notices),
      complaintsRepositoryProvider.overrideWithValue(seed.complaints),
      pinVerifierProvider.overrideWithValue(const DevPinVerifier()),
      driverAuthGatewayProvider.overrideWithValue(const DevAuthGateway()),
      driverMessagingGatewayProvider.overrideWithValue(
        const NoopMessagingGateway(),
      ),
    ],
  );
  // D3 context for the live-route screen after start (same self-serve
  // activation dev_live_route.dart uses).
  container
      .read(shiftControllerProvider.notifier)
      .activate(
        ShiftSession(
          vanId: devPreviewVanId,
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
      child: const DevFlowPreviewApp(),
    ),
  );
}

/// The real DriverApp glue (same as main.dart) with home still the
/// launching flow, pointed at the overridden dev container.
class DevFlowPreviewApp extends ConsumerWidget {
  const DevFlowPreviewApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeControllerProvider),
      locale: ref.watch(localeControllerProvider) ?? const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const SplashScreen(),
    );
  }
}
