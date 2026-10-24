/// Riverpod wiring for the tracking feature (ticket 05).
///
/// The engine singleton every other ticket drives (D1 Start Shift, D5 End
/// Shift) reads `trackingEngineProvider`, runs the permission flow once,
/// then calls start / startForActiveShift / stop (contract PRD-2 sections
/// 0.13 + 3 + F-D2 build steps).
///
/// Tests never touch this file: features override these providers via
/// `ProviderScope(overrides: [...])` with the seam fakes. The real platform
/// adapters (geolocator / battery_plus / flutter_foreground_task / Hive)
/// exist only here.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:driverapp/core/repositories/repository_providers.dart';

import 'data/battery_plus_battery_source.dart';
import 'data/flutter_foreground_task_service.dart';
import 'data/geolocator_position_source.dart';
import 'data/hive_trail_buffer.dart';
import 'domain/battery_source.dart';
import 'domain/foreground_service.dart';
import 'domain/position_source.dart';
import 'domain/tracking_engine.dart';
import 'domain/trail_buffer.dart';

export 'data/geolocator_tracking_permission_gateway.dart';
export 'domain/permission_flow.dart';
export 'domain/permission_gateway.dart';
export 'domain/tracking_engine.dart';

/// The platform GPS fix stream (geolocator), `distanceFilter = minMoveM`.
final Provider<PositionSource> positionSourceProvider =
    Provider<PositionSource>((ref) => const GeolocatorPositionSource());

/// Platform battery reads (battery_plus), one per Write Policy check.
final Provider<BatterySource> batterySourceProvider =
    Provider<BatterySource>((ref) => BatteryPlusBatterySource());

/// The Android foreground service handle (flutter_foreground_task) with the
/// persistent "Tracking active" notification.
final Provider<ForegroundServiceHandle> foregroundServiceProvider =
    Provider<ForegroundServiceHandle>(
  (ref) => const FlutterForegroundTaskService(),
);

/// Local Trail buffers, one box `trail-<tripId>` per trip.
final Provider<TrailBufferFactory> trailBufferFactoryProvider =
    Provider<TrailBufferFactory>((ref) => HiveTrailBuffer.open);

/// THE tracking engine singleton: clean start/stop/stop-flush semantics,
/// all contract writes routed through the repositories (spec seam 1).
final Provider<TrackingEngine> trackingEngineProvider =
    Provider<TrackingEngine>(
  (ref) => TrackingEngine(
    vansRepository: ref.watch(vansRepositoryProvider),
    tripsRepository: ref.watch(tripsRepositoryProvider),
    positionSource: ref.watch(positionSourceProvider),
    batterySource: ref.watch(batterySourceProvider),
    serviceHandle: ref.watch(foregroundServiceProvider),
    trailBufferFactory: ref.watch(trailBufferFactoryProvider),
  ),
);
