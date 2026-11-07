/// Firestore `in` / `not-in` value limits.
///
/// Firestore rejects a clause with more than 30 values. A route's ward list is
/// the input to `readWardsByIds`, so a route with more than 30 wards would
/// break the read. Chunking belongs in the repository: one implementation,
/// every caller benefits (B-06).
library;

/// The documented Firestore cap for one `in` / `not-in` clause.
const int maxWhereInValues = 30;

/// Splits [values] into ordered chunks of at most [max] values.
///
/// Empty input yields no chunks, so callers never issue an empty `whereIn`.
List<List<T>> chunkWhereIn<T>(List<T> values, {int max = maxWhereInValues}) {
  if (values.isEmpty) return const <List<Never>>[];
  final chunks = <List<T>>[];
  for (var start = 0; start < values.length; start += max) {
    final end = start + max < values.length ? start + max : values.length;
    chunks.add(values.sublist(start, end));
  }
  return chunks;
}
