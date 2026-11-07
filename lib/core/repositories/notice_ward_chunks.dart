/// Chunking for the notices OR query (B-04).
///
/// Firestore caps an OR query at 30 disjunctions after normalization, and a
/// `whereIn` branch fans out into one disjunction per value. The notices
/// query has two fixed branches (targetType `all` and targetType `van`), so a
/// route with 29 ward ids used to send 31 disjunctions and fail with HTTP
/// 400. Each query below carries at most [maxNoticeWardIdsPerQuery] ward ids,
/// which leaves headroom under the cap.
library;

/// 27 ward ids + the two fixed branches = 29 disjunctions, under the cap of
/// 30. The constant is public so the regression test pins the arithmetic.
const int maxNoticeWardIdsPerQuery = 27;

/// Splits [wardIds] into ordered chunks of at most
/// [maxNoticeWardIdsPerQuery]. Duplicates are dropped first: a repeated ward
/// id would spend a disjunction without widening the result.
List<List<String>> chunkNoticeWardIds(List<String> wardIds) {
  final unique = <String>[];
  final seen = <String>{};
  for (final id in wardIds) {
    if (seen.add(id)) unique.add(id);
  }

  final chunks = <List<String>>[];
  for (var start = 0; start < unique.length; start += maxNoticeWardIdsPerQuery) {
    final end = start + maxNoticeWardIdsPerQuery;
    chunks.add(
      unique.sublist(start, end > unique.length ? unique.length : end),
    );
  }
  return chunks;
}
