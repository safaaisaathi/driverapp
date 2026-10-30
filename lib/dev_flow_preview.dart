/// DEVELOPMENT-ONLY desktop entrypoint — DevFlowPreviewApp.
///
/// Runs the NEW driver-identity launching flow (Splash → Welcome → the
/// one-time permission setup → CodeStartScreen, PRD-2 §0.16) against dev
/// doubles, because Linux/Windows desktop hosts have no Firebase plugins:
/// with the real bootstrap the Firestore-backed drivers lookup degrades to
/// its error state there and nothing of the flow can be demoed. Same trick
/// as `dev_identity_start.dart` (DevDesktopSeed + seam doubles); the PIN
/// double is gone — a DevDriverLookup seeds the `drivers` collection per
/// the identity spec.
///
/// Seeded world (stable for demo checks):
/// - the setup gateway pre-grants every stage, so the Welcome CTA completes
///   without rationale screens and lands on the start-shift page;
/// - driver `AB-1234` Ramesh Patel, van-01, 3 wards — the happy path;
/// - driver `CD-5678` INACTIVE — demos the not-found flow rule;
/// - the code `XX-9999` simulates an offline lookup (lookup-failed state).
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

import 'core/config/firebase_bootstrap.dart'
    show NoopMessagingGateway, runBootstrap;
import 'core/identity/driver_identity_controller.dart';
import 'core/l10n/app_localizations.dart';
import 'core/l10n/locale_controller.dart';
import 'core/models/models.dart';
import 'core/repositories/repository_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'features/live_route/dev/desktop_demo_seed.dart'
    show DevDesktopSeed, DevTripsRepository, devSeedRouteId, devSeedVanId;
import 'features/launching/splash_screen.dart';
import 'features/shift_start/data/verify_driver_pin.dart'
    show driverMessagingGatewayProvider;
import 'features/shift_start/dev_identity_start.dart'
    show
        DevDriverLookup,
        DevIdentityStore,
        DevPermissionGateway,
        DevTrackingEngine;
import 'features/tracking/tracking_providers.dart'
    show
        trackingEngineProvider,
        trackingPermissionGatewayProvider;

/// Seeded `drivers` docs for the preview (same trio as the dev demo world;
/// see the file header for what each code demos).
Driver devDriver({
  required String code,
  required String name,
  required String phone,
  required bool active,
  List<String> wardIds = const ['ward-1', 'ward-2', 'ward-3'],
}) =>
    Driver(
      id: code,
      name: name,
      phone: phone,
      vanId: devSeedVanId,
      routeId: devSeedRouteId,
      wardIds: wardIds,
      active: active,
    );

/// The seed's trips double keys every doc by the id it is handed — and
/// Start Shift builds the trip with an empty id (the Firestore repo mints
/// the real one). This thin wrapper assigns a stable dev id so the created
/// trip, `vans.currentTripId` and the session all point somewhere real.
/// (Same wrapper as `dev_identity_start.dart`; kept local so both dev
/// entrypoints stay self-contained.)
class _IdAssigningTripsRepository extends DevTripsRepository {
  int _counter = 0;

  @override
  Future<Trip> createTrip(Trip trip) => super.createTrip(
        Trip(
          id: 'dev-trip-${++_counter}',
          vanId: trip.vanId,
          routeId: trip.routeId,
          date: trip.date,
          startedAt: trip.startedAt,
          endedAt: trip.endedAt,
          wardsDone: trip.wardsDone,
          alertedWardIds: trip.alertedWardIds,
          gpsTrail: trip.gpsTrail,
          mockLocationDetected: trip.mockLocationDetected,
        ),
      );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final seed = DevDesktopSeed();
  final container = ProviderContainer(
    overrides: [
      vansRepositoryProvider.overrideWithValue(seed.vans),
      tripsRepositoryProvider.overrideWithValue(_IdAssigningTripsRepository()),
      routesRepositoryProvider.overrideWithValue(seed.routes),
      wardsRepositoryProvider.overrideWithValue(seed.wards),
      noticesRepositoryProvider.overrideWithValue(seed.notices),
      complaintsRepositoryProvider.overrideWithValue(seed.complaints),
      driversRepositoryProvider.overrideWithValue(
        DevDriverLookup({
          'AB-1234': devDriver(
            code: 'AB-1234',
            name: 'Ramesh Patel',
            phone: '+919876543210',
            active: true,
          ),
          // Inactive on purpose: the flow treats it as not-found (0.16).
          'CD-5678': devDriver(
            code: 'CD-5678',
            name: 'Jayesh Shah',
            phone: '9123456780',
            active: false,
            wardIds: ['ward-1'],
          ),
        }),
      ),
      // The identity store is in-memory: nothing touches the
      // SharedPreferences channel on the desktop host.
      driverIdentityStoreProvider.overrideWithValue(DevIdentityStore()),
      driverMessagingGatewayProvider.overrideWithValue(
        const NoopMessagingGateway(),
      ),
      // The one-time setup pre-grants every stage on the desktop host.
      trackingPermissionGatewayProvider
          .overrideWithValue(const DevPermissionGateway()),
      trackingEngineProvider.overrideWithValue(DevTrackingEngine()),
    ],
  );
  debugPrint('dev-flow-preview: driver code AB-1234 (active), '
      'CD-5678 (inactive), XX-9999 (offline)');
  // The bootstrap runs behind the scenes exactly like main.dart; on the
  // desktop host it simply degrades (no Firebase plugins) and is never
  // awaited by the launching flow.
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
