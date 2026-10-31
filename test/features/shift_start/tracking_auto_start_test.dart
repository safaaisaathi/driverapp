/// Start/resume wiring tests for the F-D2 auto-start seam (audit fix):
/// the moment a shift session exists, the offline sync service must know
/// which trip's Trail buffer to drain on reconnect (F-D7 + §4 AC#4).
///
/// A denying permission gateway keeps the test off the platform channels and
/// off the tracking engine entirely — the attach happens BEFORE the
/// permission flow, which is exactly the contract under test.
library;

import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/features/shift_start/data/shift_tracking_auto_start.dart';
import 'package:driverapp/features/shift_start/domain/shift_session.dart';
import 'package:driverapp/features/tracking/domain/trail_buffer.dart';
import 'package:driverapp/features/tracking/offline/connectivity_source.dart';
import 'package:driverapp/features/tracking/offline/offline_providers.dart';
import 'package:driverapp/features/tracking/offline/offline_sync_service.dart';
import 'package:driverapp/features/tracking/offline/offline_write_queue.dart';
import 'package:driverapp/features/tracking/tracking_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../repositories/fake_repositories.dart';

void main() {
  ShiftSession session(String tripId) => ShiftSession(
        vanId: 'van-01',
        tripId: tripId,
        routeId: 'route-01',
        startedAt: DateTime.utc(2026, 10, 31, 5, 47),
        date: DateTime.utc(2026, 10, 30, 18, 30),
      );

  test('a shift session attaches its trip to the offline sync service '
      '(F-D7 catch-up drain)', () async {
    final service = OfflineSyncService(
      vansRepository: FakeVansRepository(),
      tripsRepository: FakeTripsRepository(),
      writeQueue: _MemoryQueue(),
      connectivitySource: _FakeConnectivity(),
      trailBufferFactory: (_) async => _StubBuffer(),
    );
    expect(service.attachedTripId, isNull);

    final starterProvider = Provider<ShiftTrackingAutoStarter>(
      (ref) => TrackingAutoStarter(ref),
    );
    final container = ProviderContainer(
      overrides: [
        offlineSyncServiceProvider.overrideWithValue(service),
        trackingPermissionGatewayProvider
            .overrideWithValue(const _DenyAllGateway()),
      ],
    );
    addTearDown(container.dispose);

    final outcome = await container
        .read(starterProvider)
        .startTrackingFor(
          session('trip-1'),
          notificationTitle: 'Tracking active',
          notificationBody: '',
        );

    expect(service.attachedTripId, 'trip-1');
    // The denial is still surfaced (the attach does not fake a start).
    expect(outcome.kind, ShiftTrackingAutoStartKind.denied);

    // A second shift (resume or a later trip) re-points the drain.
    await container.read(starterProvider).startTrackingFor(
          session('trip-2'),
          notificationTitle: 'Tracking active',
          notificationBody: '',
        );
    expect(service.attachedTripId, 'trip-2');
  });
}

class _DenyAllGateway implements TrackingPermissionGateway {
  const _DenyAllGateway();

  static const _denied = PermissionApproval.denied;

  @override
  Future<PermissionApproval> ensureLocationWhileInUse() async => _denied;

  @override
  Future<PermissionApproval> ensureLocationBackground() async => _denied;

  @override
  Future<PermissionApproval> ensureNotifications() async => _denied;

  @override
  Future<PermissionApproval> ensureBatteryOptimizationExemption() async =>
      _denied;

  @override
  Future<PermissionApproval> checkLocationWhileInUse() async => _denied;

  @override
  Future<PermissionApproval> checkLocationBackground() async => _denied;

  @override
  Future<PermissionApproval> checkNotifications() async => _denied;

  @override
  Future<PermissionApproval> checkBatteryOptimization() async => _denied;
}

class _MemoryQueue implements OfflineWriteQueue {
  @override
  Future<int> get pendingLastLocationCount async => 0;

  @override
  Future<QueuedLastLocation?> takeLastLocation() async => null;

  @override
  Future<void> enqueueLastLocation({
    required String vanId,
    required double lat,
    required double lng,
    required double speedKmph,
    required DateTime recordedAt,
  }) async {}

  @override
  Future<void> putBackLastLocation(QueuedLastLocation item) async {}
}

class _FakeConnectivity implements ConnectivitySource {
  @override
  Stream<bool> get status => const Stream<bool>.empty();
}

class _StubBuffer implements TrailBuffer {
  @override
  int get pendingCount => 0;

  @override
  Future<void> add(GpsPoint point) async {}

  @override
  Future<List<GpsPoint>> takeOldest({int? limit}) async => const <GpsPoint>[];

  @override
  Future<void> putBackOldest(List<GpsPoint> points) async {}
}
