/// DEVELOPMENT-ONLY desktop entrypoint — DevIdentityStartApp (ticket 4).
///
/// Runs the NEW driver-identity start slice (code entry → confirm card →
/// Start Shift → live route) against dev doubles, because Linux/Windows
/// desktop hosts have no Firebase plugins: with the real bootstrap the
/// Firestore-backed drivers lookup degrades to its error state and nothing
/// of the slice can be demoed. Same trick as `dev_flow_preview.dart`
/// (DevDesktopSeed + seam doubles); the PIN double is replaced by a
/// DevDriverLookup per the identity spec.
///
/// Seeded world (stable for demo checks):
/// - driver `AB-1234` Ramesh Patel, van-01, 3 wards — the happy path;
/// - driver `CD-5678` INACTIVE — demos the not-found flow rule;
/// - the code `XX-9999` simulates an offline lookup (lookup-failed state).
///
/// NOT referenced by `main.dart`; run with:
///   `flutter run -t lib/features/shift_start/dev_identity_start.dart -d linux`
///
/// Deleted at ticket 14 together with the other dev entrypoints
/// (GLOSSARY bag).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/firebase_bootstrap.dart' show NoopMessagingGateway;
import '../../core/contract/gateway_providers.dart';
import '../../core/identity/driver_identity_controller.dart';
import '../../core/identity/driver_identity_store.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_controller.dart';
import '../live_route/dev/desktop_demo_seed.dart';
import 'data/fcm_topics.dart' show driverMessagingGatewayProvider;
import 'ui/code_start_screen.dart';
import '../../features/tracking/domain/tracking_engine.dart'
    show
        TrackingEngineState,
        TrackingStartResult,
        TrackingStartOutcome,
        TrackingResumeResult,
        TrackingResumeOutcome,
        TrackingRunStatus;
import '../tracking/tracking_providers.dart'
    show
        trackingEngineProvider,
        trackingPermissionGatewayProvider,
        PermissionApproval,
        TrackingEngine,
        TrackingPermissionGateway;

/// Desktop driver-lookup double: a seeded `drivers` map behind the
/// [DriversRepository] seam. Normalizes first (a bad shape returns null
/// without any lookup, like the real repo); the magic code `XX-9999`
/// throws so the lookup-failed state is checkable at the table.
class DevDriverLookup implements DriversRepository {
  const DevDriverLookup(this._drivers);

  final Map<String, Driver> _drivers;

  @override
  Future<Driver?> fetchDriver(String rawCode) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final code = normalizeDriverCode(rawCode);
    if (code == null) return null;
    if (code == 'XX-9999') {
      throw Exception('dev: lookup unreachable (offline simulation)');
    }
    return _drivers[code];
  }
}

/// Desktop identity store double: in-memory, so nothing touches the
/// SharedPreferences channel on the desktop host.
final class DevIdentityStore implements DriverIdentityStore {
  final Map<String, Object?> _values = {};

  @override
  Future<bool?> readSetupDone() async => _values[driverSetupDoneKey] is bool
      ? _values[driverSetupDoneKey] as bool
      : null;

  @override
  Future<String?> readDriverCode() async =>
      _values[driverCodeKey] is String ? _values[driverCodeKey] as String : null;

  @override
  Future<void> writeSetupDone(bool value) async =>
      _values[driverSetupDoneKey] = value;

  @override
  Future<void> writeDriverCode(String? value) async {
    if (value == null) {
      _values.remove(driverCodeKey);
    } else {
      _values[driverCodeKey] = value;
    }
  }
}

/// Desktop permission double: every stage reports already granted, so the
/// post-activation flow runs without rationale screens in the preview.
class DevPermissionGateway implements TrackingPermissionGateway {
  const DevPermissionGateway();

  @override
  Future<PermissionApproval> ensureLocationWhileInUse() async =>
      PermissionApproval.granted;

  @override
  Future<PermissionApproval> ensureLocationBackground() async =>
      PermissionApproval.granted;

  @override
  Future<PermissionApproval> ensureNotifications() async =>
      PermissionApproval.granted;

  @override
  Future<PermissionApproval> ensureBatteryOptimizationExemption() async =>
      PermissionApproval.granted;

  @override
  Future<PermissionApproval> checkLocationWhileInUse() async =>
      PermissionApproval.granted;

  @override
  Future<PermissionApproval> checkLocationBackground() async =>
      PermissionApproval.granted;

  @override
  Future<PermissionApproval> checkNotifications() async =>
      PermissionApproval.granted;

  @override
  Future<PermissionApproval> checkBatteryOptimization() async =>
      PermissionApproval.granted;
}

/// Desktop engine double: starts immediately; nothing platform-bound.
class DevTrackingEngine implements TrackingEngine {
  @override
  Stream<TrackingEngineState> get changes =>
      const Stream<TrackingEngineState>.empty();

  @override
  TrackingEngineState get state => const TrackingEngineState(
        status: TrackingRunStatus.idle,
      );

  @override
  bool get mockLocationLatched => false;

  @override
  Future<TrackingStartResult> start({
    required String tripId,
    required String vanId,
    required String notificationTitle,
    required String notificationBody,
  }) async {
    debugPrint('dev-identity: engine.start(trip: $tripId, van: $vanId)');
    return TrackingStartResult(TrackingStartOutcome.started);
  }

  @override
  Future<TrackingResumeResult> startForActiveShift({
    required String vanId,
    required String notificationTitle,
    required String notificationBody,
  }) async =>
      const TrackingResumeResult(outcome: TrackingResumeOutcome.resumed);

  @override
  Future<void> stop() async {}
}

String _devVanIdFor(String driverCode) => devSeedVanId;

Driver _driver({
  required String code,
  required String name,
  required String phoneMasked,
  required bool active,
  List<String> wardIds = const ['ward-1', 'ward-2', 'ward-3'],
}) =>
    Driver(
      id: code,
      name: name,
      phoneMasked: phoneMasked,
      vanId: devSeedVanId,
      routeId: devSeedRouteId,
      wardIds: wardIds,
      active: active,
    );

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final seed = DevDesktopSeed();
  // The identity previews demo the FRESH start (Start creates the trip and
  // writes the 0.16 driver identity), so the seed van is parked idle - the
  // demo seed itself stays on shift for the live-route screen.
  seed.vans.parkAsIdle(devSeedVanId);
  final trips = DevTripsRepository();
  final drivers = <String, Driver>{
    'AB-1234': _driver(
      code: 'AB-1234',
      name: 'Ramesh Patel',
      phoneMasked: '98XXXXXX10',
      active: true,
    ),
    // Inactive on purpose: the flow treats it as not-found (0.16).
    'CD-5678': _driver(
      code: 'CD-5678',
      name: 'Jayesh Shah',
      phoneMasked: '91XXXXXX80',
      active: false,
      wardIds: ['ward-1'],
    ),
  };
  final container = ProviderContainer(
    overrides: [
      vansRepositoryProvider.overrideWithValue(seed.vans),
      tripsRepositoryProvider.overrideWithValue(trips),
      routesRepositoryProvider.overrideWithValue(seed.routes),
      wardsRepositoryProvider.overrideWithValue(seed.wards),
      noticesRepositoryProvider.overrideWithValue(seed.notices),
      complaintsRepositoryProvider.overrideWithValue(seed.complaints),
      driversRepositoryProvider.overrideWithValue(DevDriverLookup(drivers)),
      // CHG-0003: the bind and the shift calls are server seams now, so the
      // desktop preview supplies their doubles.
      driverSessionGatewayProvider.overrideWithValue(
        const DevDriverSessionGateway(vanIdFor: _devVanIdFor),
      ),
      shiftGatewayProvider.overrideWithValue(
        DevShiftGateway(
          trips: trips,
          vans: seed.vans,
          driverFor: (driverId) => drivers[driverId],
          routeWardIds: {
            devSeedRouteId: const ['ward-1', 'ward-2', 'ward-3'],
          },
        ),
      ),
      driverIdentityStoreProvider.overrideWithValue(DevIdentityStore()),
      driverMessagingGatewayProvider.overrideWithValue(
        const NoopMessagingGateway(),
      ),
      trackingPermissionGatewayProvider
          .overrideWithValue(const DevPermissionGateway()),
      trackingEngineProvider.overrideWithValue(DevTrackingEngine()),
    ],
  );
  debugPrint('dev-identity: codes AB-1234 (active), CD-5678 (inactive), '
      'XX-9999 (offline)');
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DevIdentityStartApp(),
    ),
  );
}

/// The real DriverApp glue (same as main.dart) with home pointed at the
/// new start-shift screen. The session itself is created by the flow on
/// Start (StartShift.execute → ShiftController.activate) and the live
/// route screen reads the seed through the same overridden container.
class DevIdentityStartApp extends ConsumerWidget {
  const DevIdentityStartApp({super.key});

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
      home: const CodeStartScreen(),
    );
  }
}
