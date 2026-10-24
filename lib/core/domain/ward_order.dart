/// Ward visiting-order logic over `routes.wardIds` (PRD-2 0.13 Flow C and
/// F-D3: the next ward in route order is what the large "Mark Ward Done"
/// button and Flow D target; any other undone ward may still be marked, but
/// it is "out of order"). Pure list logic only.
library;

/// The first ward of [orderedWardIds] that is not in [doneWardIds], or
/// `null` when the route is empty or every ward is done.
String? nextUndoneWardId(List<String> orderedWardIds, Set<String> doneWardIds) {
  for (final wardId in orderedWardIds) {
    if (!doneWardIds.contains(wardId)) return wardId;
  }
  return null;
}

/// Undone wards in route order, excluding the next-in-order one — wards the
/// driver could mark through the smaller control, i.e. everything not
/// semantically "next". Empty when the route is empty or fully done.
List<String> outOfOrderWardIds(List<String> orderedWardIds, Set<String> doneWardIds) {
  final next = nextUndoneWardId(orderedWardIds, doneWardIds);
  if (next == null) return const [];
  return [
    for (final wardId in orderedWardIds)
      if (wardId != next && !doneWardIds.contains(wardId)) wardId,
  ];
}

/// Position (0-based index) of [wardId] in the route order, or `null` when
/// the ward is not on this route. First occurrence wins.
int? positionOfWard(List<String> orderedWardIds, String wardId) {
  final index = orderedWardIds.indexOf(wardId);
  return index < 0 ? null : index;
}
