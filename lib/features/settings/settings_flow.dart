/// Settings + Trip History wiring (wireframes WF-21 / WF-22).
///
/// The screens show the CURRENT shift context (van plate + route name)
/// and the past trips of that van. Data flows only through the
/// repositories (architecture 0.11); the reads are pure Firestore
/// reads the rules already allow — no new backend surface, matching
/// the "local only" slice this branch implements.
///
/// The van identity comes from the SHIFT SESSION (D1's
/// [ShiftController]); with no session the rows degrade to
/// "Not connected" instead of reading a wrong or missing van.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/firebase_bootstrap.dart'
    show sessionGateProvider;
import '../../core/models/models.dart';
import '../../core/repositories/repository_providers.dart';
import '../shift_start/domain/shift_session.dart';

/// The van doc of the running shift (null = no session or read failed).
final FutureProvider<Van?> settingsVanProvider =
    FutureProvider.autoDispose<Van?>((ref) async {
  final session = ref.watch(shiftControllerProvider);
  if (session == null) return null;
  // F-11: a Firestore read never races boot. The dependencies are read
  // before the await; only the query waits.
  final gate = ref.watch(sessionGateProvider);
  final vans = ref.watch(vansRepositoryProvider);
  await gate;
  return vans.readVan(session.vanId);
});

/// The route doc of the running shift (null = no session or read failed).
final FutureProvider<RouteModel?> settingsRouteProvider =
    FutureProvider.autoDispose<RouteModel?>((ref) async {
  final session = ref.watch(shiftControllerProvider);
  if (session == null) return null;
  // F-11: a Firestore read never races boot. The dependencies are read
  // before the await; only the query waits.
  final gate = ref.watch(sessionGateProvider);
  final routes = ref.watch(routesRepositoryProvider);
  await gate;
  return routes.readRoute(session.routeId);
});

/// Past trips of the shift van, newest first, INCLUDING today (a live
/// trip shows as "running" — WF-22's "Today" row). Empty stream while
/// no session is running.
final StreamProvider<List<Trip>> tripHistoryProvider =
    StreamProvider.autoDispose<List<Trip>>((ref) async* {
  final session = ref.watch(shiftControllerProvider);
  if (session == null) {
    yield const <Trip>[];
    return;
  }
  // F-11: hold the query until Firebase is up. The dependencies are read
  // before the await; only the query waits.
  final gate = ref.watch(sessionGateProvider);
  final trips = ref.watch(tripsRepositoryProvider);
  await gate;
  yield* trips.watchRecentTrips(
    vanId: session.vanId,
    asOfDate: DateTime.now(),
  );
});

/// The ward total of one trip's route (for the "n of m wards" chips).
/// One-shot read per route id; trips of one van usually share a route.
final tripRouteProvider = FutureProvider.autoDispose.family<RouteModel?, String>(
  (ref, routeId) async {
    // F-11: a Firestore read never races boot.
    final gate = ref.watch(sessionGateProvider);
    final routes = ref.watch(routesRepositoryProvider);
    await gate;
    return routes.readRoute(routeId);
  },
);
