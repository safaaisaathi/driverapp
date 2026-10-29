/// D1-new Start-shift screen tests (ticket 4, PRD-2 §0.16) —
/// container-based widget tests (pattern: mock_location_banner_test.dart):
/// the screen is pumped in a ProviderContainer with repository/seam fakes,
/// so no test reaches Firebase or a platform channel.
///
/// Pinned English strings follow the shift_start_screen_test.dart pattern;
/// keys are the stable d1-* widget seams.
library;

import 'package:driverapp/core/identity/driver_identity_controller.dart';
import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repositories.dart';
import 'package:driverapp/core/config/firebase_bootstrap.dart';
import 'package:driverapp/core/theme/app_theme.dart';
import 'package:driverapp/features/shift_start/data/verify_driver_pin.dart'
    show driverMessagingGatewayProvider;
import 'package:driverapp/features/shift_start/domain/shift_session.dart';
import 'package:driverapp/features/shift_start/ui/code_start_screen.dart';
import 'package:driverapp/features/tracking/domain/tracking_engine.dart'
    show
        TrackingEngineState,
        TrackingStartResult,
        TrackingStartOutcome,
        TrackingResumeResult,
        TrackingResumeOutcome,
        TrackingRunStatus;
import 'package:driverapp/features/tracking/tracking_providers.dart'
    show
        trackingEngineProvider,
        trackingPermissionGatewayProvider,
        PermissionApproval,
        TrackingEngine,
        TrackingPermissionGateway;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/identity/driver_identity_fakes.dart';
import '../../models/sample_maps.dart';
import '../../repositories/fake_repositories.dart';

// -- pinned English strings (arb contract) ----------------------------------

const String enIdentityTitle = 'Start shift';
const String enCodeLabel = 'Code';
const String enCodeHint = 'XX-0000';
const String enCodeError = 'Wrong code. Try again.';
const String enContinue = 'Continue';
const String enStartShift = 'Start Shift';
const String enRetry = 'Retry';
const String enDriverName = 'Ramesh Patel';
const String enVanPlate = 'GJ-05-AB-1234';
const String enTwoWardsAllotted = '2 wards allotted';
const String enMaskedPhone = '98XXXXXX10';
const String enNotFoundTitle = 'Driver not found';
const String enNotFoundBody = 'Check the code with the office and try again.';
const String enLookupFailedTitle = "Couldn't check the code";
const String enLookupFailedBody = 'Check your connection and try again.';
const String enStartFailed =
    "Couldn't start the shift. Check the connection and try again.";

// -- fixtures ----------------------------------------------------------------

Van sampleVan({
  String id = 'van-01',
  String plateNo = 'GJ-05-AB-1234',
  String routeId = 'route-van',
}) =>
    Van.fromMap(<String, Object?>{
      'id': id,
      'plateNo': plateNo,
      'routeId': routeId,
      'status': 'idle',
      'lastLocation': null,
      'currentTripId': null,
      'batteryPct': 80,
    });

Driver sampleDriver({bool active = true}) => Driver.fromMap(<String, Object?>{
      ...driverDocMap(),
      'routeId': 'route-driver',
      'active': active,
    });

class RecordingMessagingGateway implements MessagingGateway {
  final List<String> topics = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> subscribeToTopic(String topic) async {
    topics.add(topic);
  }
}

/// Permission gateway that reports every check as already granted, so the
/// post-activation flow runs without ever showing a rationale screen.
class GrantAllPermissionGateway implements TrackingPermissionGateway {
  const GrantAllPermissionGateway();

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

/// Tracking engine fake that starts immediately and records the hand-over.
class RecordingTrackingEngine implements TrackingEngine {
  final List<({String tripId, String vanId})> startedWith = [];

  @override
  Stream<TrackingEngineState> get changes =>
      const Stream<TrackingEngineState>.empty();

  @override
  TrackingEngineState get state => const TrackingEngineState(
        status: TrackingRunStatus.idle,
      );

  @override
  Future<TrackingStartResult> start({
    required String tripId,
    required String vanId,
    required String notificationTitle,
    required String notificationBody,
  }) async {
    startedWith.add((tripId: tripId, vanId: vanId));
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

class FlakyDriversRepository implements DriversRepository {
  FlakyDriversRepository(this.inner, this.failsRemaining);

  final DriversRepository inner;
  int failsRemaining;

  @override
  Future<Driver?> fetchDriver(String rawCode) {
    if (failsRemaining > 0) {
      failsRemaining--;
      throw const _LookupFailed();
    }
    return inner.fetchDriver(rawCode);
  }
}

final class _LookupFailed implements Exception {
  const _LookupFailed();
}

class FailingCreateTripsRepository extends FakeTripsRepository {
  bool fail = true;

  @override
  Future<Trip> createTrip(Trip trip) async {
    if (fail) throw const _CreateTripFailed();
    return super.createTrip(trip);
  }
}

final class _CreateTripFailed implements Exception {
  const _CreateTripFailed();
}

// -- harness -----------------------------------------------------------------

Future<ProviderContainer> pumpScreen(
  WidgetTester tester, {
  required DriversRepository driversRepo,
  required FakeVansRepository vans,
  required TripsRepository trips,
  InMemoryDriverIdentityStore? identityStore,
  void Function(BuildContext context)? onShiftStarted,
}) async {
  final container = ProviderContainer(
    overrides: [
      driversRepositoryProvider.overrideWithValue(driversRepo),
      vansRepositoryProvider.overrideWithValue(vans),
      tripsRepositoryProvider.overrideWithValue(trips),
      driverIdentityStoreProvider
          .overrideWithValue(identityStore ?? InMemoryDriverIdentityStore()),
      driverMessagingGatewayProvider
          .overrideWithValue(RecordingMessagingGateway()),
      // Post-activation seams: the permission flow auto-grants and the
      // engine records, so tests never touch platform channels.
      trackingPermissionGatewayProvider
          .overrideWithValue(const GrantAllPermissionGateway()),
      trackingEngineProvider.overrideWithValue(RecordingTrackingEngine()),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        locale: const Locale('en'), // locale pinned en (project decision)
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: CodeStartScreen(onShiftStarted: onShiftStarted),
      ),
    ),
  );
  await tester.pump();
  return container;
}

/// Pumps in small steps until [finder] finds a widget or gives up.
Future<void> pumpUntil(WidgetTester tester, Finder finder,
    {int maxPumps = 60}) async {
  for (var i = 0; i < maxPumps && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
  expect(finder, findsOneWidget);
}

/// Pumps until [condition] holds (async navigation hand-over).
Future<void> pumpUntilCondition(
  WidgetTester tester,
  bool Function() condition, {
  int maxPumps = 500,
}) async {
  for (var i = 0; i < maxPumps && !condition(); i++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
  expect(condition(), isTrue, reason: 'Condition not met within pump limit');
}

RecordingTrackingEngine _engineOf(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(CodeStartScreen)),
    ).read(trackingEngineProvider) as RecordingTrackingEngine;

RecordingMessagingGateway _messagingOf(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(CodeStartScreen)),
    ).read(driverMessagingGatewayProvider) as RecordingMessagingGateway;

Future<void> submitCode(WidgetTester tester, String raw) async {
  await tester.enterText(find.byKey(const ValueKey('d1-code-field')), raw);
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('d1-code-continue')));
  await tester.pump();
}

// -- tests -------------------------------------------------------------------

void main() {
  testWidgets('invalid format: inline error, NO lookup call (a bad shape '
      'never reaches Firestore)', (tester) async {
    final drivers = FakeDriversRepository();
    await pumpScreen(
      tester,
      driversRepo: drivers,
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
    );

    await submitCode(tester, 'abc1234');

    expect(find.byKey(const ValueKey('d1-code-error')), findsOneWidget);
    expect(find.text(enCodeError), findsOneWidget);
    expect(drivers.lookups, isEmpty, reason: 'no Firestore call on a bad shape');
  });

  testWidgets('valid code: confirm card shows name, van plate, ward count '
      'and the masked phone', (tester) async {
    await pumpScreen(
      tester,
      driversRepo: FakeDriversRepository([sampleDriver()]),
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
    );

    await submitCode(tester, 'ab-1234');
    await pumpUntil(tester, find.byKey(const ValueKey('d1-confirm-card')));

    expect(find.text(enDriverName), findsOneWidget);
    expect(find.text(enVanPlate), findsOneWidget);
    expect(find.text(enTwoWardsAllotted), findsOneWidget);
    expect(find.text(enMaskedPhone), findsOneWidget);
    // The title and the code field stay on screen per the 9.6 template.
    expect(find.text(enIdentityTitle), findsOneWidget);
    expect(find.text(enCodeLabel), findsOneWidget);
  });

  testWidgets('Start Shift: activates the session, creates the trip from '
      'the driver\'s van, remembers the code and navigates', (tester) async {
    final vans = FakeVansRepository([sampleVan()]);
    final trips = FakeTripsRepository();
    final identityStore = InMemoryDriverIdentityStore();
    var navigated = false;
    await pumpScreen(
      tester,
      driversRepo: FakeDriversRepository([sampleDriver()]),
      vans: vans,
      trips: trips,
      identityStore: identityStore,
      onShiftStarted: (_) => navigated = true,
    );

    await submitCode(tester, 'AB-1234');
    await pumpUntil(tester, find.byKey(const ValueKey('d1-confirm-card')));
    await tester.tap(find.byKey(const ValueKey('d1-confirm-start')));
    await pumpUntilCondition(tester, () => navigated);

    // Session activated on the D2 seam, built from the driver's van.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CodeStartScreen)),
    );
    final session = container.read(shiftControllerProvider);
    expect(session, isNotNull);
    expect(session!.vanId, 'van-01');
    final trip = trips.trips.values.single;
    expect(trip.vanId, 'van-01');
    expect(trip.routeId, 'route-van', reason: 'routeId comes from the van');
    expect(session.tripId, trip.id);

    // Van marker writes + topic subscription (0.13 / 0.6.6).
    expect(vans.vans['van-01']!.status, VanStatus.onShift);
    expect(vans.vans['van-01']!.currentTripId, trip.id);
    expect(_messagingOf(tester).topics, ['van_van-01']);

    // The confirmed code is remembered on-device (0.16).
    expect(identityStore.storedDriverCode, 'AB-1234');

    // The tracking engine received the hand-over (old D1's post-activation
    // pattern).
    final engine = _engineOf(tester);
    expect(engine.startedWith.single.tripId, trip.id);
    expect(engine.startedWith.single.vanId, 'van-01');
  });

  testWidgets('not-found state with retry: seeding the driver afterwards '
      'recovers through the same code', (tester) async {
    final drivers = FakeDriversRepository();
    await pumpScreen(
      tester,
      driversRepo: drivers,
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
    );

    await submitCode(tester, 'ZZ-9999');
    await pumpUntil(tester, find.byKey(const ValueKey('d1-not-found')));
    expect(find.text(enNotFoundTitle), findsOneWidget);
    expect(find.text(enNotFoundBody), findsOneWidget);
    expect(drivers.lookups, ['ZZ-9999']);

    // The office seeds the driver; Retry re-looks-up the SAME code.
    drivers.drivers['ZZ-9999'] = sampleDriver();
    await tester.tap(find.byKey(const ValueKey('d1-not-found-retry')));
    await pumpUntil(tester, find.byKey(const ValueKey('d1-confirm-card')));
    expect(find.text(enDriverName), findsOneWidget);
  });

  testWidgets('lookup-failed (offline) state with retry recovers',
      (tester) async {
    final inner = FakeDriversRepository([sampleDriver()]);
    await pumpScreen(
      tester,
      driversRepo: FlakyDriversRepository(inner, 1),
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
    );

    await submitCode(tester, 'AB-1234');
    await pumpUntil(tester, find.byKey(const ValueKey('d1-lookup-failed')));
    expect(find.text(enLookupFailedTitle), findsOneWidget);
    expect(find.text(enLookupFailedBody), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('d1-lookup-failed-retry')));
    await pumpUntil(tester, find.byKey(const ValueKey('d1-confirm-card')));
    expect(find.text(enDriverName), findsOneWidget);
  });

  testWidgets('start write failure: localized error, the CTA stays '
      'available and retry starts once the write succeeds', (tester) async {
    final trips = FailingCreateTripsRepository();
    var navigated = false;
    await pumpScreen(
      tester,
      driversRepo: FakeDriversRepository([sampleDriver()]),
      vans: FakeVansRepository([sampleVan()]),
      trips: trips,
      onShiftStarted: (_) => navigated = true,
    );

    await submitCode(tester, 'AB-1234');
    await pumpUntil(tester, find.byKey(const ValueKey('d1-confirm-card')));
    await tester.tap(find.byKey(const ValueKey('d1-confirm-start')));
    await pumpUntil(tester, find.text(enStartFailed));
    expect(trips.trips, isEmpty, reason: 'the failed write created no doc');

    trips.fail = false;
    await tester.tap(
      find.byKey(const ValueKey('d1-confirm-start')).hitTestable(),
    );
    await pumpUntilCondition(tester, () => navigated);
    expect(trips.trips, hasLength(1));
  });

  testWidgets('code hint and label render on the fresh screen', (tester) async {
    await pumpScreen(
      tester,
      driversRepo: FakeDriversRepository(),
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
    );

    expect(find.text(enIdentityTitle), findsOneWidget);
    expect(find.text(enCodeLabel), findsOneWidget);
    expect(find.text(enCodeHint), findsOneWidget);
    expect(find.text(enContinue), findsOneWidget);
    expect(find.byKey(const ValueKey('d1-code-error')), findsNothing);
  });
}
