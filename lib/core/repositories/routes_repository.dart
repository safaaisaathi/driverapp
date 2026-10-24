import '../models/models.dart';

/// Data access for the `routes` collection (0.2) — the visiting order a van
/// follows (Glossary).
abstract class RoutesRepository {
  /// Reads one route by id; `null` when the route doc doesn't exist.
  Future<RouteModel?> readRoute(String routeId);
}
