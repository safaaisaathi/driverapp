/// DEBUG ENTRYPOINT — tracking demo WITHOUT ticket 05's D1 dependency
/// (ticket 05 deliverable: "removed/flagged at integration").
///
/// NOT referenced by `main.dart`; the integration ticket wires this in (or
/// deletes it) once D1's PIN + Start Shift flow exists. To run the demo
/// locally, temporarily point `main.dart` at [runDevTrackingApp].
///
/// The seeded van id below is a @visibleForTesting constant, clearly
/// dev-only. The demo creates its OWN trip in the seeded emulator data via
/// the trips repository (D1 owns the real `vans.currentTripId` write; the
/// engine only READS it for resume).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:driverapp/core/config/firebase_bootstrap.dart';
import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repository_providers.dart';

import 'tracking_providers.dart';

/// Seeded van id for the demo (must exist in the emulator seed).
@visibleForTesting
const String devTrackingVanId = 'van-01';

/// `main()`-like entrypoint for the debug demo (never used by main.dart).
/// Boots Firebase/emulators FIRST (ticket 02), then shows the demo screen.
Future<void> runDevTrackingApp() async {
  final container = ProviderContainer();
  await runBootstrap(container); // degrades gracefully when emulators down
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DevTrackingMaterialApp(),
    ),
  );
}

class DevTrackingMaterialApp extends StatelessWidget {
  const DevTrackingMaterialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dev tracking demo',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const DevTrackingScreen(),
    );
  }
}

/// One-screen demo:
/// 1. run the four-stage permission flow (contract order),
/// 2. create a dev trip through the trips repository,
/// 3. start the engine (persistent notification, Write Policy writes),
/// 4. Stop equals exactly what End Shift will call (final trail flush).
class DevTrackingScreen extends ConsumerStatefulWidget {
  const DevTrackingScreen({super.key});

  @override
  ConsumerState<DevTrackingScreen> createState() => _DevTrackingScreenState();
}

class _DevTrackingScreenState extends ConsumerState<DevTrackingScreen> {
  TrackingPermissionStage? _failedStage;
  bool _anyGpsOff = false;
  TrackingEngineState _engineState = TrackingEngineState.idle;

  @override
  void initState() {
    super.initState();
    ref.read(trackingEngineProvider).changes.listen((state) {
      if (!mounted) return;
      setState(() => _engineState = state);
    });
  }

  Future<void> _start() async {
    final localizations = AppLocalizations.of(context)!;

    // (1) Permission flow in contract order — localized claim lines live in
    // the arb files; the screen already shows all four.
    final report = await PermissionFlowController(
      ref.read(devTrackingPermissionGatewayProvider),
    ).requestAll();

    if (!mounted) return;
    if (!report.allGranted) {
      // Denials never crash: show the localized denied state and stop here;
      // the app stays usable.
      setState(() {
        _failedStage = report.failedStage;
        _anyGpsOff = report.results.values
            .any((approval) => approval == PermissionApproval.gpsOff);
      });
      return;
    }

    // (2) Dev-only trip (D1 will own this part after integration).
    final van = await ref
        .read(vansRepositoryProvider)
        .watchVan(devTrackingVanId)
        .first;
    final created = await ref.read(tripsRepositoryProvider).createTrip(
          Trip(
            id: '',
            vanId: devTrackingVanId,
            routeId: van?.routeId ?? 'route-01',
            date: DateTime.now(),
            startedAt: DateTime.now(),
            endedAt: null,
            wardsDone: const <WardDone>[],
            alertedWardIds: const <String>[],
            gpsTrail: const <GpsPoint>[],
            mockLocationDetected: false,
          ),
        );

    // (3) Start the singleton engine.
    final result = await ref.read(trackingEngineProvider).start(
          tripId: created.id,
          vanId: devTrackingVanId,
          notificationTitle: localizations.trackingNotificationTitle,
          notificationBody: localizations.trackingNotificationBody,
        );
    if (!result.isStarted && mounted) {
      setState(() => _engineState = ref.read(trackingEngineProvider).state);
    }
  }

  Future<void> _stop() async {
    // (4) Same call D5 End Shift will make (final trail flush included).
    await ref.read(trackingEngineProvider).stop();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final running =
        _engineState.status == TrackingRunStatus.running ||
            _engineState.status == TrackingRunStatus.failed;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.trackingNotificationTitle),
      ),
      body: Center(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(_stateLabel(context),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (!_anyStageDenied(_engineState)) ...[
              // The four ONE-line explanations, localized (arb keys).
              Text(localizations.trackingPermissionWhileInUseClaim),
              Text(localizations.trackingPermissionBackgroundClaim),
              Text(localizations.trackingPermissionNotificationsClaim),
              Text(localizations.trackingPermissionBatteryClaim),
              const SizedBox(height: 16),
              const SizedBox(height: 8),
            ],
            Text(
              _anyGpsOff
                  ? localizations.trackingGpsOff
                  : _failedStage == null
                      ? ''
                      : localizations.trackingPermissionDenied,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: running ? null : _start,
              child: const Text('Dev: start tracking'),
            ),
            FilledButton(
              onPressed: running ? _stop : null,
              child: const Text('Dev: stop (flushes trail)'),
            ),
          ],
        ),
      ),
    );
  }

  bool _anyStageDenied(TrackingEngineState state) => _failedStage != null;

  String _stateLabel(BuildContext context) {
    if (_engineState.status == TrackingRunStatus.running) {
      return '${AppLocalizations.of(context)!.trackingNotificationTitle} '
          '(trip: ${_engineState.tripId})';
    }
    return switch (_engineState.status) {
      TrackingRunStatus.idle => 'idle',
      TrackingRunStatus.running => 'running',
      TrackingRunStatus.failed => 'failed: ${_engineState.error}',
    };
  }
}

/// Wired directly here (NOT through tracking_providers.dart) so the demo
/// owns nothing about the production wiring; the integration ticket removes
/// this file together with the pointer from main.
final devTrackingPermissionGatewayProvider = Provider<TrackingPermissionGateway>(
  (ref) => const GeolocatorTrackingPermissionGateway(),
);
