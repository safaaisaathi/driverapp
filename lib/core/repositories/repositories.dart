/// Barrel for the repository spine (0.11): one abstract repository per
/// collection, a Firestore implementation each, and Riverpod providers so
/// tests can swap fakes at seam 1 (spec Testing Decisions).
library;

export 'complaints_repository.dart';
export 'notices_repository.dart';
export 'repository_providers.dart';
export 'routes_repository.dart';
export 'trips_repository.dart';
export 'vans_repository.dart';
export 'wards_repository.dart';
