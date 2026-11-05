/// Start Shift core tests (ticket 7, PRD-2 §0.16, CHG-0003):
/// `StartShift.execute` takes the confirmed `Driver`, calls the `startShift`
/// callable, signs in with the returned token and subscribes the van topic.
/// The trip, the van marker and the ward snapshot are the SERVER's writes, so
/// the fake gateway is what proves them. Pure Dart — no Firebase, no platform
/// channels.
library;

import 'package:driverapp/core/config/firebase_bootstrap.dart'
    show MessagingGateway;
import 'package:driverapp/core/contract/reason_codes.dart';
import 'package:driverapp/core/contract/shift_gateway.dart';
import 'package:driverapp/core/domain/ist_clock.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/features/shift_start/domain/start_shift.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../models/sample_maps.dart';
import '../../repositories/fake_repositories.dart';

Van sampleVan({
  String id = 'van-01',
  String routeId = 'route-van',
  String status = 'idle',
  String? currentTripId,
}) =>
    Van.fromMap(<String, Object?>{
      'id': id,
      'plateNo': 'GJ-05-AB-1234',
      'routeId': routeId,
      'status': status,
      'lastLocation': null,
      'currentTripId': currentTripId,
      'batteryPct': 80,
    });

Driver sampleDriver({String id = 'AB-1234', List<String>? wardIds}) =>
    Driver.fromMap(<String, Object?>{
      ...driverDocMap(id: id),
      'wardIds': wardIds ?? const ['ward-01', 'ward-02'],
    });

class RecordingMessagingGateway implements MessagingGateway {
  final List<String> topics = [];
  @override
  Future<void> init() async {}
  @override
  Future<void> subscribeToTopic(String topic) async {
    topics.add(topic);
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    topics.remove(topic);
  }
}

void main() {
  late FakeTripsRepository trips;
  late FakeVansRepository vans;
  late FakeDriverSessionGateway session;
  late FakeShiftGateway gateway;
  late RecordingMessagingGateway messaging;
  late StartShift startShift;

  setUp(() {
    trips = FakeTripsRepository();
    vans = FakeVansRepository([sampleVan()]);
    session = FakeDriverSessionGateway(
      bindingFor: (code) => DriverBinding(
        token: 'bind-$code',
        vanId: 'van-01',
        driverId: code,
        claimMode: 'firstClaim',
      ),
    );
    gateway = FakeShiftGateway(
      trips: trips,
      vans: vans,
      drivers: [sampleDriver()],
      clock: () => DateTime.utc(2026, 10, 20, 2),
    );
    messaging = RecordingMessagingGateway();
    startShift = StartShift(
      gateway: gateway,
      session: session,
      messaging: messaging,
    );
  });

  group('StartShift.execute goes through the callable (CHG-0003)', () {
    test('sends the driver id and the IST day instant, signs in with the '
        'returned token and builds the session', () async {
      final driver = sampleDriver(wardIds: const ['ward-01', 'ward-02']);
      final now = DateTime.utc(2026, 10, 20, 2, 30); // 08:00 IST

      final result = await startShift.execute(driver, now);

      // The callable received the confirmed driver and the IST midnight.
      expect(gateway.startCalls, hasLength(1));
      expect(gateway.startCalls.single.driverId, 'AB-1234');
      expect(gateway.startCalls.single.date, utcStartOfIstDay(now));

      // The trip is the SERVER's write (mirrored by the fake).
      final trip = trips.trips.values.single;
      expect(trip.vanId, 'van-01');
      expect(trip.routeId, 'route-01'); // from the driver doc, server-side
      expect(trip.driverId, 'AB-1234');
      expect(trip.wardIds, const ['ward-01', 'ward-02']);
      expect(isSameDayIST(trip.date, now), isTrue);

      final van = vans.vans['van-01']!;
      expect(van.status, VanStatus.onShift);
      expect(van.currentTripId, trip.id);

      // The fresh token carries the trip claim: the app must sign in with it
      // before the first trail write.
      expect(session.signedInTokens, ['token-AB-1234-${trip.id}']);

      expect(result.vanId, 'van-01');
      expect(result.tripId, trip.id);
      expect(result.routeId, 'route-01');
      expect(result.date, utcStartOfIstDay(now));

      expect(messaging.topics, ['van_van-01']);
    });

    test('a callable refusal surfaces as a ContractException with the '
        'server reason code', () async {
      gateway.startError =
          const ContractException(ReasonCode.vanHeldByAnotherDriver);

      await expectLater(
        startShift.execute(sampleDriver(), DateTime.utc(2026, 10, 20, 2)),
        throwsA(
          isA<ContractException>().having(
            (error) => error.code,
            'code',
            ReasonCode.vanHeldByAnotherDriver,
          ),
        ),
      );
      expect(trips.trips, isEmpty, reason: 'the server wrote nothing');
      expect(session.signedInTokens, isEmpty);
    });
  });

  group('isResumable', () {
    test('only an on_shift van with an open-trip marker is resumable', () {
      expect(
        startShift.isResumable(
          sampleVan(
            status: 'on_shift',
            currentTripId: 'trip-1',
          ),
        ),
        isTrue,
      );
      expect(startShift.isResumable(sampleVan()), isFalse);
      expect(
        startShift.isResumable(
          sampleVan(status: 'on_shift'),
        ),
        isFalse,
      );
    });
  });
}
