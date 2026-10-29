import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'complaints_repository.dart';
import 'drivers_repository.dart';
import 'firestore/firestore_complaints_repository.dart';
import 'firestore/firestore_drivers_repository.dart';
import 'firestore/firestore_notices_repository.dart';
import 'firestore/firestore_routes_repository.dart';
import 'firestore/firestore_trips_repository.dart';
import 'firestore/firestore_vans_repository.dart';
import 'firestore/firestore_wards_repository.dart';
import 'notices_repository.dart';
import 'routes_repository.dart';
import 'trips_repository.dart';
import 'vans_repository.dart';
import 'wards_repository.dart';

/// Riverpod wiring for the repository spine (0.11: data access only through
/// repositories; spec seam 1).
///
/// Feature tests never touch this file: they run under a `ProviderScope(overrides:
/// [...])` with in-memory fakes (test/repositories/fake_repositories.dart) in
/// place of every provider below:
///
/// ```dart
/// ProviderScope(
///   overrides: [vansRepositoryProvider.overrideWithValue(fakeVans)],
///   child: ...,
/// )
/// ```

/// The shared [FirebaseFirestore] instance with offline persistence enabled
/// (0.13 relies on the persistent cache for dead-zone survival; the wiring
/// lives here so it does not depend on any screen).
///
/// Reading this provider does not initialize Firebase; the app layer does that
/// before the first read. Settings must be set before any other Firestore
/// call, which provider creation guarantees (Riverpod initializes lazily,
/// once per ProviderContainer).
final Provider<FirebaseFirestore> firebaseFirestoreProvider =
    Provider<FirebaseFirestore>((ref) {
  final firestore = FirebaseFirestore.instance;
  firestore.settings = const Settings(
    persistenceEnabled: true,
    // Trail + notice cache are the offline survival layer (0.13); no LRU cap.
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  return firestore;
});

final Provider<VansRepository> vansRepositoryProvider =
    Provider<VansRepository>(
  (ref) => FirestoreVansRepository(ref.watch(firebaseFirestoreProvider)),
);

final Provider<TripsRepository> tripsRepositoryProvider =
    Provider<TripsRepository>(
  (ref) => FirestoreTripsRepository(ref.watch(firebaseFirestoreProvider)),
);

final Provider<NoticesRepository> noticesRepositoryProvider =
    Provider<NoticesRepository>(
  (ref) => FirestoreNoticesRepository(ref.watch(firebaseFirestoreProvider)),
);

final Provider<ComplaintsRepository> complaintsRepositoryProvider =
    Provider<ComplaintsRepository>(
  (ref) => FirestoreComplaintsRepository(ref.watch(firebaseFirestoreProvider)),
);

final Provider<DriversRepository> driversRepositoryProvider =
    Provider<DriversRepository>(
  (ref) => FirestoreDriversRepository(ref.watch(firebaseFirestoreProvider)),
);

final Provider<WardsRepository> wardsRepositoryProvider =
    Provider<WardsRepository>(
  (ref) => FirestoreWardsRepository(ref.watch(firebaseFirestoreProvider)),
);

final Provider<RoutesRepository> routesRepositoryProvider =
    Provider<RoutesRepository>(
  (ref) => FirestoreRoutesRepository(ref.watch(firebaseFirestoreProvider)),
);
