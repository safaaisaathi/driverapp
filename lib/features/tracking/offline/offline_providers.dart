/// Riverpod wiring for the offline sync feature (F-D7, ticket 12).
///
/// Tests never touch this file: they override the providers below with seam
/// fakes via `ProviderScope(overrides: [...])`. The real platform adapter
/// (connectivity_plus) exists only here; the repositories and the Trail
/// buffer factory are the shared tracking/repo providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:driverapp/core/repositories/repository_providers.dart';

import 'data/connectivity_plus_source.dart';
import '../tracking_providers.dart';
import 'connectivity_source.dart';
import 'offline_sync_service.dart';
import 'offline_write_queue.dart';

/// Network reachability (connectivity_plus real adapter).
final Provider<ConnectivitySource> connectivitySourceProvider =
    Provider<ConnectivitySource>((ref) => ConnectivityPlusSource());

/// Durable Hive queue for the latest unsent `vans.lastLocation` candidate.
final Provider<OfflineWriteQueue> offlineWriteQueueProvider =
    Provider<OfflineWriteQueue>((ref) => HiveOfflineWriteQueue());

/// THE offline sync singleton: started at app bootstrap (after Firebase
/// init), told about the active trip via [OfflineSyncService.attachTrip]
/// at start/resume, flushed on every reconnect or manual `flushNow`.
final Provider<OfflineSyncService> offlineSyncServiceProvider =
    Provider<OfflineSyncService>(
      (ref) => OfflineSyncService(
        vansRepository: ref.watch(vansRepositoryProvider),
        tripsRepository: ref.watch(tripsRepositoryProvider),
        writeQueue: ref.watch(offlineWriteQueueProvider),
        connectivitySource: ref.watch(connectivitySourceProvider),
        trailBufferFactory: ref.watch(trailBufferFactoryProvider),
      ),
    );

/// The subtle un-synced points surface: a plain counter (a badge/count,
/// never an alarm). Emits the current count on
/// subscribe, then on every change; drains toward 0 as flushes succeed.
final StreamProvider<int> unsyncedPointsCountProvider = StreamProvider<int>(
  (ref) => ref.watch(offlineSyncServiceProvider).pendingCountStream,
);
