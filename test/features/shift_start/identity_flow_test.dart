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

import 'package:driverapp/core/config/firebase_bootstrap.dart';
import 'package:driverapp/core/domain/ist_clock.dart';
import 'package:driverapp/core/identity/driver_identity_controller.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repositories.dart';
import 'package:driverapp/features/shift_start/data/verify_driver_pin.dart'
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
        driverMessagingGatewayProvider.overrideWithValue(messaging),
        driverIdentityStoreProvider.overrideWithValue(identityStore),
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
