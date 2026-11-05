/// F-11: the boot session gate is app-wide, not just on the first lookup.
///
/// A degraded boot used to leave D2, D3 and D4 free to query Firestore before
/// `Firebase.initializeApp` answered. These tests hold the gate closed and pin
/// that no repository read leaves until it resolves.
library;

import 'dart:async';

import 'package:driverapp/core/config/firebase_bootstrap.dart'
    show sessionGateProvider;
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repository_providers.dart';
import 'package:driverapp/features/live_route/live_route_providers.dart';
import 'package:driverapp/features/notices/domain/notices_flow.dart';
import 'package:driverapp/features/pending_reports/domain/pending_reports_flow.dart';
import 'package:driverapp/features/shift_start/domain/shift_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../repositories/fake_repositories.dart';

void main() {
  Van sampleVan() => const Van(
        id: 'van-01',
        plateNo: 'GJ-01-V-2201',
        routeId: 'route-01',
        status: VanStatus.idle,
        lastLocation: null,
        currentTripId: null,
        batteryPct: 100,
      );

  RouteModel sampleRoute() => const RouteModel(
        id: 'route-01',
        name: 'West Loop',
        wardIds: ['ward-1', 'ward-2'],
        scheduledStartTime: '07:30',
      );

  ShiftSession sampleSession() => ShiftSession(
        vanId: 'van-01',
        tripId: 'trip-1',
        routeId: 'route-01',
        startedAt: DateTime.utc(2026, 11, 5, 8),
        date: DateTime.utc(2026, 11, 5),
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('vanDocProvider holds the D2 van read until the gate resolves',
      () async {
    final gate = Completer<void>();
    final vans = _RecordingVansRepository([sampleVan()]);
    final container = ProviderContainer(
      overrides: [
        vansRepositoryProvider.overrideWithValue(vans),
        sessionGateProvider.overrideWithValue(gate.future),
      ],
    );
    addTearDown(container.dispose);

    final sub = container.listen(vanDocProvider('van-01'), (_, _) {});
    await settle();
    expect(vans.watchCalls, 0, reason: 'no Firestore read before boot');

    gate.complete();
    await settle();
    expect(vans.watchCalls, 1);
    sub.close();
  });

  test('the notices load holds the route read until the gate resolves',
      () async {
    final gate = Completer<void>();
    final routes = _RecordingRoutesRepository([sampleRoute()]);
    final container = ProviderContainer(
      overrides: [
        routesRepositoryProvider.overrideWithValue(routes),
        noticesRepositoryProvider.overrideWithValue(FakeNoticesRepository()),
        sessionGateProvider.overrideWithValue(gate.future),
      ],
    );
    addTearDown(container.dispose);
    container.read(shiftControllerProvider.notifier).activate(sampleSession());

    final sub = container.listen(noticesFlowProvider, (_, _) {});
    await settle();
    expect(routes.readCalls, 0, reason: 'no Firestore read before boot');

    gate.complete();
    await settle();
    expect(routes.readCalls, 1);
    sub.close();
  });

  test('the pending reports load holds the route read until the gate resolves',
      () async {
    final gate = Completer<void>();
    final routes = _RecordingRoutesRepository([sampleRoute()]);
    final container = ProviderContainer(
      overrides: [
        routesRepositoryProvider.overrideWithValue(routes),
        complaintsRepositoryProvider
            .overrideWithValue(FakeComplaintsRepository()),
        sessionGateProvider.overrideWithValue(gate.future),
      ],
    );
    addTearDown(container.dispose);
    container.read(shiftControllerProvider.notifier).activate(sampleSession());

    final load =
        container.read(pendingReportsFlowProvider.notifier).ensureLoaded();
    await settle();
    expect(routes.readCalls, 0, reason: 'no Firestore read before boot');

    gate.complete();
    await load;
    expect(routes.readCalls, 1);
  });
}

final class _RecordingVansRepository extends FakeVansRepository {
  _RecordingVansRepository(super.seed);

  int watchCalls = 0;

  @override
  Stream<Van?> watchVan(String vanId) {
    watchCalls++;
    return super.watchVan(vanId);
  }
}

final class _RecordingRoutesRepository extends FakeRoutesRepository {
  _RecordingRoutesRepository(super.seed);

  int readCalls = 0;

  @override
  Future<RouteModel?> readRoute(String routeId) {
    readCalls++;
    return super.readRoute(routeId);
  }
}
