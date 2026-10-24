import '../models/models.dart';

/// Data access for the `wards` collection (0.2).
abstract class WardsRepository {
  /// Loads `wards` by id (the route map screen resolves `routes.wardIds` into
  /// wards; missing ids are simply absent from the result).
  Future<List<Ward>> readWardsByIds(List<String> ids);

  /// Watch the wards served by one route (`wards.routeId == routeId`) — the
  /// live route screen keeps its ward overlays current through this.
  Stream<List<Ward>> watchRouteWards(String routeId);
}
