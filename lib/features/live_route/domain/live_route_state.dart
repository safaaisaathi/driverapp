/// The Live Route screen state (one of: loading, empty, error, data per the
/// demo-driver contract, spec user story 24) plus the pure reducer that turns
/// repository AsyncValues into it.
///
/// Pure — mockable and unit-testable with fakes, no Riverpod types beyond
/// `AsyncValue` itself and no widgets.
library;

import 'package:flutter/foundation.dart'
    show debugPrint, listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driverapp/core/models/models.dart';

import 'van_marker_state.dart';
import 'ward_steps.dart';

/// Why the screen is empty (distinct messages — arb keys `routeEmptyMessage`
/// and `routeMissingMessage`).
enum LiveRouteEmptyReason {
  /// The route doc exists but has no visitable wards (either no `wardIds`,
  /// or none of them resolved to `wards` docs).
  noWards,

  /// There is no `routes` doc for the van's `routeId` (data problem).
  routeMissing,
}

/// Sealed UI states of the D2 Live Route screen.
sealed class LiveRouteState {
  const LiveRouteState();

  /// Convenience for screens: the data instance (or null).
  LiveRouteData? get asData => this is LiveRouteData ? this as LiveRouteData : null;
}

/// Streams are still producing their first value.
class LiveRouteLoading extends LiveRouteState {
  const LiveRouteLoading();

  @override
  bool operator ==(Object other) =>
      other is LiveRouteLoading && other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'LiveRouteLoading';
}

/// A stream errored (or the repositories threw). The screen offers a retry
/// button that invalidates the providers.
class LiveRouteError extends LiveRouteState {
  const LiveRouteError();

  @override
  bool operator ==(Object other) =>
      other is LiveRouteError && other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'LiveRouteError';
}

/// The route exists but has nothing to show.
class LiveRouteEmpty extends LiveRouteState {
  final LiveRouteEmptyReason reason;

  const LiveRouteEmpty(this.reason);

  @override
  bool operator ==(Object other) =>
      other is LiveRouteEmpty &&
      other.runtimeType == runtimeType &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(runtimeType, reason);

  @override
  String toString() => 'LiveRouteEmpty($reason)';
}

/// Everything the screen renders: ward steps in route order (done ticked,
/// first undone "next"), the van marker, optional offline banner flag.
class LiveRouteData extends LiveRouteState {
  final String routeId;

  final String routeName;

  final List<WardStep> wardSteps;

  /// Null while the van doc has no `lastLocation` yet — the map shows the
  /// wards; the marker appears from the van doc stream the moment it lands.
  final VanMarkerState? vanMarker;

  /// True when the offline seam reports the device is offline (banner over
  /// the map; cached data keeps rendering — Firestore persistence, F-D7).
  final bool isOffline;

  const LiveRouteData({
    required this.routeId,
    required this.routeName,
    required this.wardSteps,
    required this.vanMarker,
    required this.isOffline,
  });

  /// The next-in-order ward (first undone), or null when the route is
  /// complete — the "next" highlight slot.
  WardStep? get nextWard {
    for (final step in wardSteps) {
      if (step.isNext) return step;
    }
    return null;
  }

  /// Completed wards of the route.
  int get doneCount => wardSteps.where((step) => step.isDone).length;

  @override
  bool operator ==(Object other) =>
      other is LiveRouteData &&
      other.runtimeType == runtimeType &&
      other.routeId == routeId &&
      other.routeName == routeName &&
      listEquals(other.wardSteps, wardSteps) &&
      other.vanMarker == vanMarker &&
      other.isOffline == isOffline;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        routeId,
        routeName,
        Object.hashAll(wardSteps),
        vanMarker,
        isOffline,
      );

  @override
  String toString() =>
      'LiveRouteData($routeId "$routeName" ${wardSteps.length} wards '
      'done $doneCount van=$vanMarker offline=$isOffline)';
}

/// Pure reducer: combines the five repository-backed AsyncValues the screen
/// subscribes to (van doc stream, open-trip stream, route read, route wards
/// stream, offline seam) into one [LiveRouteState].
///
/// Precedence (demo-driver contract — nothing adapts to surprises):
/// 1. any error → [LiveRouteError] (the failed piece defines it; keep the
///    state one-value so the screen cannot half-render);
/// 2. else any [AsyncValue.isLoading] with no value → [LiveRouteLoading];
/// 3. else the route is missing or wardless → [LiveRouteEmpty];
/// 4. else [LiveRouteData]. A null van doc (stream emits `null` before the
///    doc exists) does NOT block: only `lastLocation` is needed for the
///    marker, and a missing marker renders as none until the doc lands.
LiveRouteState combineLiveRouteState({
  required AsyncValue<Van?> van,
  required AsyncValue<Trip?> trip,
  required AsyncValue<RouteModel?> route,
  required AsyncValue<List<Ward>> wards,
  required bool isOffline,
  required DateTime now,
}) {
  AsyncValue<Object?>? error;
  for (final value in [van, trip, route, wards]) {
    if (value.hasError) {
      error = value;
      // Which leg failed and why — never guess on a device again.
      final err = value.error;
      var detail = err.toString();
      // Riverpod wraps callback errors: unwrap for the message chain.
      if (detail.length < 8) detail = '${err.runtimeType}';
      debugPrint('live-route: error leg raw:');
      debugPrint(detail);
      final st = value.stackTrace;
      if (st != null) debugPrint(st.toString());
      break;
    }
  }
  if (error != null) {
    return const LiveRouteError();
  }

  final loading = [van, trip, route, wards]
      .any((value) => value.isLoading && !value.hasValue);
  if (loading) {
    return const LiveRouteLoading();
  }

  final routeModel = route.value;
  if (routeModel == null) {
    return const LiveRouteEmpty(LiveRouteEmptyReason.routeMissing);
  }

  final resolvedWards = _resolveWardsInOrder(
    orderedWardIds: routeModel.wardIds,
    loadedWards: wards.value ?? const <Ward>[],
  );
  if (resolvedWards.isEmpty) {
    return const LiveRouteEmpty(LiveRouteEmptyReason.noWards);
  }

  final done = TripDoneState.of(trip.value);
  // A van doc with no `lastLocation` yet (or no van doc at all) renders no
  // marker — never a pin at (0,0) (Null Island).
  final vanLocation = van.value?.lastLocation;
  final vanMarker = vanLocation == null ? null : VanMarkerState.of(vanLocation, now);

  return LiveRouteData(
    routeId: routeModel.id,
    routeName: routeModel.name,
    wardSteps: deriveWardSteps(
      // Deduped, doc-resolved order — duplicate route ids collapse to the
      // first occurrence (ruling 5).
      orderedWardIds: [for (final ward in resolvedWards) ward.id],
      wardsById: {for (final ward in resolvedWards) ward.id: ward},
      done: done,
    ),
    vanMarker: vanMarker,
    isOffline: isOffline,
  );
}

/// Wards in `routes.wardIds` order, ids not resolved to a doc dropped, and
/// duplicate ids removed (first occurrence wins — ruling 5).
List<Ward> _resolveWardsInOrder({
  required List<String> orderedWardIds,
  required List<Ward> loadedWards,
}) {
  final byId = {for (final ward in loadedWards) ward.id: ward};
  final seen = <String>{};
  return [
    for (final id in orderedWardIds)
      if (byId[id] != null && seen.add(id)) byId[id]!
  ];
}
