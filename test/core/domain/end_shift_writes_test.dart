/// End-shift write set (F-D5, ruling #29, `topics.json` cleanupRule).
///
/// Both entry points share [writeEndShift], so the topic cleanup is tested
/// here once: the callable lands first, then the van topic is left, then
/// tracking stops. A failed cleanup must never reopen or block the shift.
library;

import 'package:driverapp/core/config/firebase_bootstrap.dart'
    show MessagingGateway;
import 'package:driverapp/core/contract/reason_codes.dart';
import 'package:driverapp/core/domain/end_shift_writes.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../repositories/fake_repositories.dart';

void main() {
  late FakeTripsRepository trips;
  late FakeVansRepository vans;
  late FakeShiftGateway gateway;
  late _RecordingMessaging messaging;
  var stopCalls = 0;

  setUp(() {
    trips = FakeTripsRepository([
      Trip(
        id: 'trip-1',
        vanId: 'van-01',
        routeId: 'route-01',
        driverId: 'drv-01',
        wardIds: const <String>[],
        date: DateTime.utc(2026, 11, 5),
        startedAt: DateTime.utc(2026, 11, 5, 8),
        endedAt: null,
        wardsDone: const <WardDone>[],
        alertedWardIds: const <String>[],
        gpsTrail: const <GpsPoint>[],
        mockLocationDetected: false,
      ),
    ]);
    vans = FakeVansRepository([
      const Van(
        id: 'van-01',
        plateNo: 'MH-01',
        routeId: 'route-01',
        status: VanStatus.onShift,
        lastLocation: null,
        currentTripId: 'trip-1',
        batteryPct: null,
        depot: null,
      ),
    ]);
    gateway = FakeShiftGateway(trips: trips, vans: vans);
    messaging = _RecordingMessaging();
    stopCalls = 0;
  });

  Future<void> end() => writeEndShift(
        gateway: gateway,
        tripId: 'trip-1',
        stopTracking: () async => stopCalls++,
        messaging: messaging,
        vanTopic: 'van_van-01',
      );

  test('ends the trip, unsubscribes the van topic, then stops', () async {
    await end();

    expect(gateway.endCalls, ['trip-1']);
    expect(messaging.unsubscribed, ['van_van-01']);
    expect(stopCalls, 1);
    expect(trips.trips['trip-1']!.endedAt, isNotNull);
  });

  test('a failed unsubscribe still stops tracking and ends the shift',
      () async {
    messaging.failUnsubscribeWith = StateError('fcm down');

    await end();

    expect(messaging.unsubscribed, isEmpty);
    expect(stopCalls, 1);
    expect(trips.trips['trip-1']!.endedAt, isNotNull);
  });

  test('a failed end call rethrows and touches neither topic nor tracking',
      () async {
    gateway.endError = const ContractException(ReasonCode.internal);

    await expectLater(end(), throwsA(isA<ContractException>()));

    expect(messaging.unsubscribed, isEmpty);
    expect(stopCalls, 0);
    expect(trips.trips['trip-1']!.endedAt, isNull);
  });

  test('without a messaging seam the topic step is skipped', () async {
    await writeEndShift(
      gateway: gateway,
      tripId: 'trip-1',
      stopTracking: () async => stopCalls++,
    );

    expect(messaging.unsubscribed, isEmpty);
    expect(stopCalls, 1);
  });
}

final class _RecordingMessaging implements MessagingGateway {
  final unsubscribed = <String>[];
  Object? failUnsubscribeWith;

  @override
  Future<void> init() async {}

  @override
  Future<void> subscribeToTopic(String topic) async {}

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    if (failUnsubscribeWith != null) throw failUnsubscribeWith!;
    unsubscribed.add(topic);
  }
}
