/// Driver-identity start-shift flow (ticket 4, PRD-2 §0.16) — pure Dart
/// tests over the flow controller: no widgets, no Firebase, no platform
/// channels. The fakes are the same repository doubles the feature tests
/// use; the identity store is the ticket-3 in-memory fake.
///
/// The contract under test:
/// - a bad code shape shows the inline error and makes NO lookup call;
/// - an unknown OR inactive driver is not-found (the flow rule; the seam
///   still returns inactive docs);
/// - an outage is lookupFailed, retryable;
/// - Start creates the trip from the DRIVER's van, marks the van, activates
///   the shift session and remembers the confirmed code on-device.
library;

import 'dart:async';

import 'package:driverapp/core/config/firebase_bootstrap.dart';
import 'package:driverapp/core/domain/ist_clock.dart';
import 'package:driverapp/core/identity/driver_identity_controller.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repositories.dart';
import 'package:driverapp/features/shift_start/data/fcm_topics.dart'
    show driverMessagingGatewayProvider;
import 'package:driverapp/features/shift_start/domain/identity_flow.dart';
import 'package:driverapp/features/shift_start/domain/shift_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/identity/driver_identity_fakes.dart';
import '../../models/sample_maps.dart';
import '../../repositories/fake_repositories.dart';

Van sampleVan({
  String id = 'van-01',
  String plateNo = 'GJ-05-AB-1234',
  String routeId = 'route-van',
  String status = 'idle',
  String? currentTripId,
}) =>
    Van.fromMap(<String, Object?>{
      'id': id,
      'plateNo': plateNo,
      'routeId': routeId,
      'status': status,
      'lastLocation': null,
      'currentTripId': currentTripId,
      'batteryPct': 80,
    });

/// The seeded driver, with the routeId deliberately DIFFERENT from the
/// van's — Start must take the route from the van (routeId handling
/// unchanged by 0.16), never from the driver doc.
Driver sampleDriver({bool active = true}) => Driver.fromMap(<String, Object?>{
      ...driverDocMap(),
      'routeId': 'route-driver',
      'active': active,
    });

/// A second driver for the ticket-5 change-code reset.
Driver otherDriver() => Driver.fromMap(<String, Object?>{
      ...driverDocMap(id: 'CD-5678'),
      'name': 'Suresh Shah',
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

class FlakyTripsRepository extends FakeTripsRepository {
  FlakyTripsRepository(this.failsRemaining);

  int failsRemaining;

  @override
  Future<Trip> createTrip(Trip trip) {
    if (failsRemaining > 0) {
      failsRemaining--;
      throw const _CreateTripFailed();
    }
    return super.createTrip(trip);
  }
}

final class _CreateTripFailed implements Exception {
  const _CreateTripFailed();
}

/// One wired container per test: fakes in, flow controller out.
final class Harness {
  Harness({
    Iterable<Driver>? driversSeed,
    DriversRepository? driversRepo,
    List<Van>? vansSeed,
    TripsRepository? tripsRepo,
    Future<void>? sessionGate,
  })  : drivers = FakeDriversRepository(driversSeed),
        vans = FakeVansRepository(vansSeed),
        trips = tripsRepo ?? FakeTripsRepository(),
        messaging = RecordingMessagingGateway(),
        identityStore = InMemoryDriverIdentityStore() {
    container = ProviderContainer(
      overrides: [
        driversRepositoryProvider
            .overrideWithValue(driversRepo ?? drivers),
        vansRepositoryProvider.overrideWithValue(vans),
        tripsRepositoryProvider.overrideWithValue(trips),
        // Ruling #28: the welcome card resolves the route name at lookup
        // time; the fake keeps that read off Firestore.
        routesRepositoryProvider.overrideWithValue(
          FakeRoutesRepository([
            RouteModel.fromMap(routeDocMap()),
            RouteModel.fromMap(routeDocMap(id: 'route-driver')),
          ]),
        ),
        driverMessagingGatewayProvider.overrideWithValue(messaging),
        driverIdentityStoreProvider.overrideWithValue(identityStore),
        // The cold-start gate (issue #18) defaults to immediate in tests;
        // the race test scripts it with a closed completer.
        if (sessionGate != null)
          sessionGateProvider.overrideWithValue(sessionGate),
      ],
    );
  }

  late final ProviderContainer container;

  final FakeDriversRepository drivers;
  final FakeVansRepository vans;
  final TripsRepository trips;
  final RecordingMessagingGateway messaging;
  final InMemoryDriverIdentityStore identityStore;

  IdentityFlowState get state => container.read(identityFlowProvider);

  Future<void> submit(String raw) =>
      container.read(identityFlowProvider.notifier).submitCode(raw);

  Future<void> start() =>
      container.read(identityFlowProvider.notifier).start();

  Future<void> retry() =>
      container.read(identityFlowProvider.notifier).retry();

  void resetToEntry() =>
      container.read(identityFlowProvider.notifier).resetToEntry();
}

void main() {
  group('IdentityFlowController (ticket 4, PRD-2 §0.16)', () {
    test('bad shape: inline invalidCode, NO lookup call (a bad code never '
        'reaches Firestore)', () async {
      final harness = Harness(vansSeed: [sampleVan()]);

      await harness.submit('abc1234');

      expect(harness.state.phase, IdentityFlowPhase.invalidCode);
      expect(harness.drivers.lookups, isEmpty);
    });

    test('the first lookup waits for the boot session gate: a read never '
        'races the anonymous sign-in (issue #18)', () async {
      final gate = Completer<void>();
      final harness = Harness(
        driversSeed: [sampleDriver()],
        vansSeed: [sampleVan()],
        sessionGate: gate.future,
      );

      final submit = harness.submit('ab-1234');
      await Future<void>.delayed(Duration.zero);
      // Gate closed: the flow is looking up, but NO read left the device.
      expect(harness.state.phase, IdentityFlowPhase.lookingUp);
      expect(harness.drivers.lookups, isEmpty);

      // The session lands: the lookup proceeds and confirms.
      gate.complete();
      await submit;
      expect(harness.drivers.lookups, ['AB-1234']);
      expect(harness.state.phase, IdentityFlowPhase.confirmReady);
    });

    test('valid code: lookup → confirm card data; the code is remembered '
        'at the moment of confirm', () async {
      final harness = Harness(
        driversSeed: [sampleDriver()],
        vansSeed: [sampleVan()],
      );

      // Any case, without the dash (spec story 7).
      await harness.submit('ab-1234');

      expect(harness.state.phase, IdentityFlowPhase.confirmReady);
      expect(harness.state.driver?.name, 'Ramesh Patel');
      expect(harness.state.driver?.wardIds, hasLength(2));
      expect(harness.state.vanPlate, 'GJ-05-AB-1234');
      expect(harness.drivers.lookups, ['AB-1234']);
      expect(harness.identityStore.storedDriverCode, 'AB-1234');
    });

    test('unknown code: notFound (a well-formed code with no doc)',
        () async {
      final harness = Harness(vansSeed: [sampleVan()]);

      await harness.submit('ZZ-9999');

      expect(harness.state.phase, IdentityFlowPhase.notFound);
      expect(harness.state.driver, isNull);
      expect(harness.drivers.lookups, ['ZZ-9999']);
    });

    test('inactive driver: notFound (the seam returns the doc, the flow '
        'treats it as not-found)', () async {
      final harness = Harness(
        driversSeed: [sampleDriver(active: false)],
        vansSeed: [sampleVan()],
      );

      await harness.submit('AB-1234');

      expect(harness.state.phase, IdentityFlowPhase.notFound);
      expect(harness.state.driver, isNull);
    });

    test('lookup outage: lookupFailed; retry re-looks-up and recovers',
        () async {
      final innerDrivers = FakeDriversRepository([sampleDriver()]);
      final harness = Harness(
        driversRepo: FlakyDriversRepository(innerDrivers, 1),
        vansSeed: [sampleVan()],
      );

      await harness.submit('AB-1234');
      expect(harness.state.phase, IdentityFlowPhase.lookupFailed);

      await harness.retry();
      expect(harness.state.phase, IdentityFlowPhase.confirmReady);
      expect(innerDrivers.lookups, ['AB-1234']);
    });

    test('notFound retry re-looks-up the same code', () async {
      final harness = Harness(vansSeed: [sampleVan()]);

      await harness.submit('ZZ-9999');
      expect(harness.state.phase, IdentityFlowPhase.notFound);

      // The office seeds the driver between the two attempts.
      harness.drivers.drivers['ZZ-9999'] = sampleDriver();
      await harness.retry();

      expect(harness.state.phase, IdentityFlowPhase.confirmReady);
      expect(harness.drivers.lookups, ['ZZ-9999', 'ZZ-9999']);
    });

    test('full lifecycle: start creates the trip from the VAN, marks the '
        'van on_shift, activates the session and subscribes the topic',
        () async {
      final harness = Harness(
        driversSeed: [sampleDriver()],
        vansSeed: [sampleVan()],
      );
      await harness.submit('AB-1234');
      final before = DateTime.now();

      await harness.start();

      expect(harness.state.phase, IdentityFlowPhase.onShift);
      final session = harness.state.session;
      expect(session, isNotNull);
      expect(session!.vanId, 'van-01');

      // Trip doc: vanId + routeId come from the VAN doc, never the driver.
      expect(harness.trips, isA<FakeTripsRepository>());
      final trips = (harness.trips as FakeTripsRepository).trips;
      expect(trips, hasLength(1));
      final trip = trips.values.single;
      expect(trip.vanId, 'van-01');
      expect(trip.routeId, 'route-van');
      // 0.16 trip contract: the confirmed code + the driver's allotted wards
      // land on the trip doc (the van came from `drivers.vanId`).
      expect(trip.driverId, 'AB-1234');
      expect(trip.wardIds, const ['ward-01', 'ward-02']);
      expect(
        isSameDayIST(trip.date, before),
        isTrue,
        reason: 'trips.date is today IST',
      );

      // Van marker writes (behaviour rules 3).
      final van = harness.vans.vans['van-01']!;
      expect(van.status, VanStatus.onShift);
      expect(van.currentTripId, trip.id);

      // FCM topic `van_{vanId}` (0.6.6).
      expect(harness.messaging.topics, ['van_van-01']);

      // The session reached ShiftController (the D2 seam).
      final live = harness.container.read(shiftControllerProvider);
      expect(live?.tripId, trip.id);
      expect(live?.startedAt, trip.startedAt);
    });

    test('start write failure: startFailed keeps the confirm data; retry '
        'starts without duplicating the trip', () async {
      final flakyTrips = FlakyTripsRepository(1);
      final harness = Harness(
        driversSeed: [sampleDriver()],
        vansSeed: [sampleVan()],
        tripsRepo: flakyTrips,
      );
      await harness.submit('AB-1234');

      await harness.start();
      expect(harness.state.phase, IdentityFlowPhase.startFailed);
      expect(harness.state.driver?.name, 'Ramesh Patel');

      await harness.retry();
      expect(harness.state.phase, IdentityFlowPhase.onShift);
      expect(
        (harness.trips as FakeTripsRepository).trips,
        hasLength(1),
        reason: 'the failed write created no doc; the retry created one',
      );
    });

    test('start guard: start() with no confirmed driver is a no-op',
        () async {
      final harness = Harness(vansSeed: [sampleVan()]);

      await harness.start();

      expect(harness.state.phase, IdentityFlowPhase.initial);
      expect((harness.trips as FakeTripsRepository).trips, isEmpty);
    });

    test('a shared van: another driver\'s open trip is NEVER taken over — '
        'the start fails with the retryable inline error', () async {
      final trips = FakeTripsRepository([
        Trip.fromMap(<String, Object?>{
          'id': 'trip-1',
          'vanId': 'van-01',
          'routeId': 'route-van',
          'driverId': 'AB-1001',
          'wardIds': <String>['ward-01'],
          'date': DateTime.now(),
          'startedAt': DateTime.now(),
          'endedAt': null,
          'wardsDone': [],
          'alertedWardIds': [],
          'gpsTrail': [],
          'mockLocationDetected': false,
        }),
      ]);
      final harness = Harness(
        driversSeed: [sampleDriver()],
        vansSeed: [
          sampleVan(status: 'on_shift', currentTripId: 'trip-1'),
        ],
        tripsRepo: trips,
      );
      await harness.submit('AB-1234');

      await harness.start();

      // The blocked resume lands on the retryable startFailed state — the
      // same inline error a write failure shows, never a crash.
      expect(harness.state.phase, IdentityFlowPhase.startFailed);
      expect(harness.state.driver?.id, 'AB-1234');
      // No take-over: the other driver's trip doc is untouched.
      expect(trips.trips['trip-1']!.driverId, 'AB-1001');
      expect(trips.trips, hasLength(1));
    });

    test('resetToEntry (ticket 5 change-code): drops the confirm context '
        'back to a resting entry, the remembered code stays', () async {
      final harness = Harness(
        driversSeed: [sampleDriver(), otherDriver()],
        vansSeed: [sampleVan()],
      );
      await harness.submit('AB-1234');
      expect(harness.state.phase, IdentityFlowPhase.confirmReady);

      harness.resetToEntry();

      // A resting entry state with no confirm data left behind.
      expect(harness.state.phase, IdentityFlowPhase.initial);
      expect(harness.state.driver, isNull);
      // Change-code does NOT clear the remembered code; only a new confirm
      // overwrites it.
      expect(harness.identityStore.storedDriverCode, 'AB-1234');

      // The entry path works right after, and its confirm overwrites.
      await harness.submit('CD-5678');
      expect(harness.state.phase, IdentityFlowPhase.confirmReady);
      expect(harness.state.driver?.name, 'Suresh Shah');
      expect(harness.identityStore.storedDriverCode, 'CD-5678');

      // A running shift is never clobbered by the reset.
      await harness.start();
      expect(harness.state.phase, IdentityFlowPhase.onShift);
      harness.resetToEntry();
      expect(harness.state.phase, IdentityFlowPhase.onShift);
    });
  });

  group('launch-time resume (ruling #27)', () {
    Trip openTrip({String driverId = 'AB-1234'}) => Trip.fromMap(<String, Object?>{
          ...tripDocMapOpen(),
          'driverId': driverId,
        });

    test('a still-running shift reattaches with no write and no tap', () async {
      final harness = Harness(
        driversSeed: [sampleDriver()],
        vansSeed: [
          sampleVan(status: 'on_shift', currentTripId: 'trip-01'),
        ],
        tripsRepo: FakeTripsRepository([openTrip()]),
      );

      await harness.submit('AB-1234');
      expect(harness.state.phase, IdentityFlowPhase.confirmReady);
      // Ruling #28: the route name is resolved at lookup time.
      expect(harness.state.routeName, 'Godhra Fort Route');

      final session =
          await harness.container.read(identityFlowProvider.notifier).resumeIfActive();

      expect(session?.tripId, 'trip-01');
      expect(session?.vanId, 'van-01');
      expect(harness.state.phase, IdentityFlowPhase.onShift);
      // Resume reads the open trip, it never creates a second one.
      expect((harness.trips as FakeTripsRepository).trips.length, 1);
      expect(harness.vans.vans['van-01']!.status, VanStatus.onShift);
    });

    test('no running shift: the welcome card keeps its one-tap start', () async {
      final harness = Harness(
        driversSeed: [sampleDriver()],
        vansSeed: [sampleVan()], // idle, no currentTripId
      );

      await harness.submit('AB-1234');
      final session =
          await harness.container.read(identityFlowProvider.notifier).resumeIfActive();

      expect(session, isNull);
      expect(harness.state.phase, IdentityFlowPhase.confirmReady);
    });

    test("another driver's shift is never taken over at launch", () async {
      final harness = Harness(
        driversSeed: [sampleDriver()],
        vansSeed: [
          sampleVan(status: 'on_shift', currentTripId: 'trip-01'),
        ],
        tripsRepo: FakeTripsRepository([openTrip(driverId: 'CD-5678')]),
      );

      await harness.submit('AB-1234');
      final session =
          await harness.container.read(identityFlowProvider.notifier).resumeIfActive();

      expect(session, isNull);
      expect(harness.state.phase, IdentityFlowPhase.confirmReady);
    });
  });

  group('maskDriverPhone (confirm card, 0.16 masked phone)', () {
    test('strips +91 and shows first 2 + last 2 digits', () {
      expect(maskDriverPhone('+919876543210'), '98XXXXXX10');
      expect(maskDriverPhone('9876543210'), '98XXXXXX10');
    });

    test('non-phone junk degrades without throwing', () {
      expect(maskDriverPhone('123'), '123');
      expect(maskDriverPhone(''), '');
    });
  });
}
