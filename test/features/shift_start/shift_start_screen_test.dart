import 'package:driverapp/core/config/firebase_bootstrap.dart';
import 'package:driverapp/core/domain/ist_clock.dart';
import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repositories.dart';
import 'package:driverapp/core/theme/app_theme.dart';
import 'package:driverapp/features/shift_start/data/verify_driver_pin.dart';
import 'package:driverapp/features/shift_start/domain/shift_session.dart';
import 'package:driverapp/features/shift_start/ui/shift_start_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../repositories/fake_repositories.dart';

/// D1 Shift Start widget tests — spec seam 1: every Firebase touch is a
/// fake behind the repository / F-D1 data seams; platform channels are
/// never reached. The callable contract is programmed against 0.7
/// (`{vanId,pin}` → `{token}`, `DriverPinException` kinds for wrong pin /
/// lockout / outage).

const String enWrongPin = 'Wrong PIN. Try again.';
const String enLockedOut =
    'Too many attempts. Please wait a few minutes and try again.';
const String enStartFailed =
    "Couldn't start the shift. Check the connection and try again.";
const String enVansEmpty = 'No vans found';
const String enVanListError = "Couldn't load vans";
const String enRetry = 'Retry';
const String enStartShift = 'Start Shift';
const String enResumeShift = 'Resume shift';

Map<String, Object?> sampleVanDocMap({
  String id = 'van-1',
  String plateNo = 'GJ-05-AB-1234',
  String routeId = 'route-1',
  String status = 'idle',
  String? currentTripId,
}) =>
    <String, Object?>{
      'id': id,
      'plateNo': plateNo,
      'routeId': routeId,
      'status': status,
      'lastLocation': null,
      'currentTripId': currentTripId,
      'batteryPct': 80,
    };

Van sampleVan({
  String id = 'van-1',
  String plateNo = 'GJ-05-AB-1234',
  String routeId = 'route-1',
  String status = 'idle',
  String? currentTripId,
}) =>
    Van.fromMap(sampleVanDocMap(
      id: id,
      plateNo: plateNo,
      routeId: routeId,
      status: status,
      currentTripId: currentTripId,
    ));

RouteModel sampleRoute({String id = 'route-1', String name = 'Vasna–Bavka'}) =>
    RouteModel.fromMap(<String, Object?>{
      'id': id,
      'name': name,
      'wardIds': <String>['ward-1', 'ward-2'],
      'scheduledStartTime': '07:30',
    });

/// Scriptable PIN verifier fake: correct [pin] → token; a fixed [kind]
/// override (test-only) always throws that failure.
DriverPinVerifier pinVerifier({
  String pin = '1234',
  DriverPinFailureKind? kind,
}) =>
    _ScriptedPinVerifier(correctPin: pin, fixedKind: kind);

final class _ScriptedPinVerifier implements DriverPinVerifier {
  const _ScriptedPinVerifier({
    required this.correctPin,
    this.fixedKind,
  });

  final String correctPin;
  final DriverPinFailureKind? fixedKind;

  @override
  Future<String> verifyPin({
    required String vanId,
    required String pin,
  }) async {
    if (fixedKind != null) {
      throw DriverPinException(fixedKind!, cause: 'scripted');
    }
    if (pin == correctPin) return 'custom-token-1';
    throw const DriverPinException(
      DriverPinFailureKind.wrongPin,
      cause: 'scripted',
    );
  }
}

class RecordingAuthGateway implements DriverAuthGateway {
  final List<String> tokens = [];

  @override
  Future<String> signInWithCustomToken(String token) async {
    tokens.add(token);
    return 'driver-uid-1';
  }
}

class RecordingMessagingGateway implements MessagingGateway {
  final List<String> topics = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> subscribeToTopic(String topic) async {
    topics.add(topic);
  }
}

/// Delegating van repo whose [readVans] fails [failsRemaining] times —
/// the load-fail / retry path.
class FlakyVansRepository implements VansRepository {
  FlakyVansRepository(this.inner, this.failsRemaining);

  final VansRepository inner;
  int failsRemaining;

  @override
  Future<List<Van>> readVans() {
    if (failsRemaining > 0) {
      failsRemaining--;
      throw const _ReadVansFailed();
    }
    return inner.readVans();
  }

  @override
  Stream<Van?> watchVan(String vanId) => inner.watchVan(vanId);

  @override
  Future<void> updateLastLocation({
    required String vanId,
    required double lat,
    required double lng,
    required double speedKmph,
    DateTime? updatedAt,
  }) =>
      inner.updateLastLocation(
        vanId: vanId,
        lat: lat,
        lng: lng,
        speedKmph: speedKmph,
        updatedAt: updatedAt,
      );

  @override
  Future<void> updateStatus(String vanId, VanStatus status) =>
      inner.updateStatus(vanId, status);

  @override
  Future<void> updateBatteryPct(String vanId, int batteryPct) =>
      inner.updateBatteryPct(vanId, batteryPct);

  @override
  Future<void> updateCurrentTripId(String vanId, String? tripId) =>
      inner.updateCurrentTripId(vanId, tripId);
}

final class _ReadVansFailed implements Exception {
  const _ReadVansFailed();
}

class FailingCreateTripsRepository extends FakeTripsRepository {
  @override
  Future<Trip> createTrip(Trip trip) async {
    throw const _CreateTripFailed();
  }
}

final class _CreateTripFailed implements Exception {
  const _CreateTripFailed();
}

// -- harness ----------------------------------------------------------------

Future<ProviderScope> pumpHarness(
  WidgetTester tester, {
  required VansRepository vans,
  required TripsRepository trips,
  required FakeRoutesRepository routes,
  required DriverPinVerifier verifier,
  DriverAuthGateway? auth,
  MessagingGateway? messaging,
  void Function(BuildContext context)? onShiftStarted,
}) async {
  final scope = ProviderScope(
    overrides: [
      vansRepositoryProvider.overrideWithValue(vans),
      tripsRepositoryProvider.overrideWithValue(trips),
      routesRepositoryProvider.overrideWithValue(routes),
      pinVerifierProvider.overrideWithValue(verifier),
      driverAuthGatewayProvider
          .overrideWithValue(auth ?? RecordingAuthGateway()),
      driverMessagingGatewayProvider
          .overrideWithValue(messaging ?? RecordingMessagingGateway()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: ShiftStartScreen(onShiftStarted: onShiftStarted),
    ),
  );
  await tester.pumpWidget(scope);
  return scope;
}

/// Pumps in small steps until [finder] finds a widget or gives up.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 60,
}) async {
  for (var i = 0; i < maxPumps && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
  expect(finder, findsOneWidget);
}

/// Lets async controller work land without expecting a specific widget.
Future<void> pumpFrames(WidgetTester tester, [int pumps = 12]) async {
  for (var i = 0; i < pumps; i++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
}

Future<void> selectVanAndVerify(
  WidgetTester tester, {
  String plate = 'GJ-05-AB-1234',
  String pin = '1234',
}) async {
  await pumpUntil(tester, find.text(plate));
  await tester.tap(find.text(plate));
  await tester.pump();
  final field = find.byKey(const ValueKey('d1-pin-field'));
  await pumpUntil(tester, field);
  await tester.enterText(field, pin);
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('d1-verify-button')));
  await tester.pump();
}

// -- tests ------------------------------------------------------------------

void main() {
  testWidgets('van list: loading then plates + assigned route names',
      (tester) async {
    await pumpHarness(
      tester,
      vans: FakeVansRepository([
        sampleVan(),
        sampleVan(id: 'van-2', plateNo: 'GJ-05-CD-9999', routeId: 'route-none'),
      ]),
      trips: FakeTripsRepository(),
      routes: FakeRoutesRepository([sampleRoute()]),
      verifier: pinVerifier(),
    );
    // The assigned route name resolves through vans.routeId → routes.
    await pumpUntil(tester, find.text('Route: Vasna–Bavka'));
    expect(find.text('GJ-05-AB-1234'), findsOneWidget);
    // A route-miss falls back to the localized "route not set" line and
    // never blocks picking.
    await pumpUntil(tester, find.text('Route not set'));
    expect(find.text('GJ-05-CD-9999'), findsOneWidget);
    expect(find.text(enVansEmpty), findsNothing);
  });

  testWidgets('van list: empty state', (tester) async {
    await pumpHarness(
      tester,
      vans: FakeVansRepository(),
      trips: FakeTripsRepository(),
      routes: FakeRoutesRepository(),
      verifier: pinVerifier(),
    );
    await pumpUntil(tester, find.text(enVansEmpty));
  });

  testWidgets('van list: error/degraded state, Retry recovers',
      (tester) async {
    final innerVans = FakeVansRepository([sampleVan()]);
    await pumpHarness(
      tester,
      vans: FlakyVansRepository(innerVans, 1),
      trips: FakeTripsRepository(),
      routes: FakeRoutesRepository(),
      verifier: pinVerifier(),
    );
    await pumpUntil(tester, find.text(enVanListError));
    await tester.tap(find.text(enRetry));
    await pumpUntil(tester, find.text('GJ-05-AB-1234'));
  });

  testWidgets(
      'wrong PIN shows the friendly localized message and survives retries',
      (tester) async {
    await pumpHarness(
      tester,
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
      routes: FakeRoutesRepository([sampleRoute()]),
      verifier: pinVerifier(),
    );
    await selectVanAndVerify(tester, pin: '0000');
    await pumpUntil(tester, find.text(enWrongPin));
    // Retry once more (wrong again): no crash, message still shown.
    await tester.enterText(find.byKey(const ValueKey('d1-pin-field')), '1111');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('d1-verify-button')));
    await tester.pump();
    await pumpUntil(tester, find.text(enWrongPin));
    // Then the right PIN moves past verification without crashing.
    await tester.enterText(find.byKey(const ValueKey('d1-pin-field')), '1234');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('d1-verify-button')));
    await pumpUntil(tester, find.text(enStartShift));
  });

  testWidgets('5-try lockout from the callable surfaces clearly, no crash',
      (tester) async {
    await pumpHarness(
      tester,
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
      routes: FakeRoutesRepository([sampleRoute()]),
      verifier: pinVerifier(kind: DriverPinFailureKind.lockedOut),
    );
    await selectVanAndVerify(tester);
    await pumpUntil(tester, find.text(enLockedOut));
    // The entry stays usable (app state intact, retries allowed later).
    expect(find.byKey(const ValueKey('d1-verify-button')), findsOneWidget);
  });

  testWidgets('correct PIN signs in with the returned custom token',
      (tester) async {
    final auth = RecordingAuthGateway();
    await pumpHarness(
      tester,
      vans: FakeVansRepository([sampleVan()]),
      trips: FakeTripsRepository(),
      routes: FakeRoutesRepository([sampleRoute()]),
      verifier: pinVerifier(),
      auth: auth,
    );
    await selectVanAndVerify(tester);
    await pumpUntil(tester, find.text(enStartShift));
    // verifyDriverPin's token reached the sign-in gateway; D1 is ready.
    expect(auth.tokens, ['custom-token-1']);
    expect(find.text('Van confirmed. Ready to start.'), findsOneWidget);
  });

  testWidgets(
      'fresh Start creates the exact 0.2 trip shape, marks the van, '
      'subscribes van_{vanId}, navigates and activates ShiftController',
      (tester) async {
    final routes = FakeRoutesRepository([sampleRoute()]);
    final vansRepo = FakeVansRepository([sampleVan()]);
    final tripsRepo = FakeTripsRepository();
    final messaging = RecordingMessagingGateway();
    var navigated = false;
    await pumpHarness(
      tester,
      vans: vansRepo,
      trips: tripsRepo,
      routes: routes,
      verifier: pinVerifier(),
      messaging: messaging,
      onShiftStarted: (_) => navigated = true,
    );
    final before = DateTime.now();
    await selectVanAndVerify(tester);
    await pumpUntil(tester, find.text(enStartShift));
    await tester.tap(find.text(enStartShift));
    await pumpFrames(tester);

    // Trip doc: exact 0.2 shape on the fresh branch (single trip).
    expect(tripsRepo.trips, hasLength(1));
    final trip = tripsRepo.trips.values.single;
    expect(trip.vanId, 'van-1');
    expect(trip.routeId, 'route-1'); // routeId taken from the van
    final after = DateTime.now();
    expect(
      isSameDayIST(trip.date, before) || isSameDayIST(trip.date, after),
      isTrue,
      reason: 'trips.date is today IST',
    );
    expect(!trip.startedAt.isBefore(before) && !trip.startedAt.isAfter(after),
        isTrue, reason: 'startedAt stamped around the tap');
    expect(trip.endedAt, isNull);
    expect(trip.wardsDone, isEmpty);
    expect(trip.alertedWardIds, isEmpty);
    expect(trip.gpsTrail, isEmpty);
    expect(trip.mockLocationDetected, isFalse);

    // Van marker writes (behaviour rules 3): status + currentTripId.
    final van = vansRepo.vans['van-1']!;
    expect(van.status, VanStatus.onShift);
    expect(van.currentTripId, trip.id);

    // FCM topic `van_{vanId}` after shift start (0.6.6).
    expect(messaging.topics, ['van_van-1']);

    // ShiftController session (ticket 05 engine seam).
    final container =
        ProviderScope.containerOf(tester.element(find.byType(ShiftStartScreen)));
    final session = container.read(shiftControllerProvider);
    expect(session != null, isTrue);
    if (session != null) {
      expect(session.vanId, 'van-1');
      expect(session.tripId, trip.id);
      expect(session.routeId, 'route-1');
      expect(session.startedAt, trip.startedAt);
      expect(session.date, trip.date);
    }

    // Nav stack advanced via the seam.
    expect(navigated, isTrue);
  });

  testWidgets(
      'resume branch: stays on existing trip, no duplicate doc, '
      'button reads Resume shift', (tester) async {
    const resumeTripId = 'trip-7';
    final routes = FakeRoutesRepository([sampleRoute()]);
    final vansRepo = FakeVansRepository([
      sampleVan(status: 'on_shift', currentTripId: resumeTripId),
    ]);
    final tripsRepo = FakeTripsRepository([
      Trip(
        id: resumeTripId,
        vanId: 'van-1',
        routeId: 'route-1',
        date: utcStartOfIstDay(DateTime.now()),
        startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        endedAt: null,
        wardsDone: const <WardDone>[],
        alertedWardIds: const <String>[],
        gpsTrail: const <GpsPoint>[],
        mockLocationDetected: false,
      ),
    ]);
    final messaging = RecordingMessagingGateway();
    var navigated = false;
    await pumpHarness(
      tester,
      vans: vansRepo,
      trips: tripsRepo,
      routes: routes,
      verifier: pinVerifier(),
      messaging: messaging,
      onShiftStarted: (_) => navigated = true,
    );
    await selectVanAndVerify(tester);
    await pumpUntil(tester, find.text(enResumeShift));
    expect(find.text(enStartShift), findsNothing);
    await tester.tap(find.text(enResumeShift));
    await pumpFrames(tester);

    // Reattach: the seeded trip is still the ONLY trip doc.
    expect(tripsRepo.trips, hasLength(1));
    expect(tripsRepo.trips.keys, [resumeTripId]);

    // No redundant van writes flipped anything (already on_shift with a
    // matching currentTripId; resume writes nothing).
    final van = vansRepo.vans['van-1']!;
    expect(van.status, VanStatus.onShift);
    expect(van.currentTripId, resumeTripId);
    final session = ProviderScope.containerOf(
      tester.element(find.byType(ShiftStartScreen)),
    ).read(shiftControllerProvider);
    expect(session?.tripId, resumeTripId);
    expect(session?.startedAt, tripsRepo.trips[resumeTripId]!.startedAt);
    // Topic still subscribed for a resumed van.
    expect(messaging.topics, ['van_van-1']);
    expect(navigated, isTrue);
  });

  testWidgets('failed shift writes surface an error state (not a crash)',
      (tester) async {
    final routes = FakeRoutesRepository([sampleRoute()]);
    final tripsRepo = FailingCreateTripsRepository();
    await pumpHarness(
      tester,
      vans: FakeVansRepository([sampleVan()]),
      trips: tripsRepo,
      routes: routes,
      verifier: pinVerifier(),
    );
    await selectVanAndVerify(tester);
    await pumpUntil(tester, find.text(enStartShift));
    await tester.tap(find.text(enStartShift));
    await pumpFrames(tester);
    await pumpUntil(tester, find.text(enStartFailed));

    // No trip doc landed; van untouched on the failed fresh start.
    expect(tripsRepo.trips, isEmpty);

    // The screen recovers to the ready state (button back on).
    final buttonFinder =
        find.byKey(const ValueKey('d1-start-button')).hitTestable();
    expect(buttonFinder, findsOneWidget);
  });
}
