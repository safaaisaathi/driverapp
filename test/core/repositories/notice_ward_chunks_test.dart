/// B-04 regression test: the notices query must never exceed Firestore's
/// 30-disjunction OR cap. Two fixed branches (all, van) + the chunk size.
library;

import 'package:driverapp/core/repositories/notice_ward_chunks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('two fixed branches plus one chunk stay under 30', () {
    expect(2 + maxNoticeWardIdsPerQuery, lessThanOrEqualTo(30));
  });

  test('no wards gives no ward chunk (the two-branch query)', () {
    expect(chunkNoticeWardIds(const []), isEmpty);
  });

  test('a small route is one chunk', () {
    expect(
      chunkNoticeWardIds(const ['ward-1', 'ward-2', 'ward-3']),
      [
        ['ward-1', 'ward-2', 'ward-3'],
      ],
    );
  });

  test('the old 29-ward cliff becomes two queries', () {
    final wards = [for (var i = 1; i <= 29; i++) 'ward-$i'];
    final chunks = chunkNoticeWardIds(wards);

    expect(chunks, hasLength(2));
    expect(chunks[0], hasLength(maxNoticeWardIdsPerQuery));
    expect(chunks[1], hasLength(2));
    expect(chunks.expand((chunk) => chunk), wards);
  });

  test('chunks never exceed the cap and keep route order', () {
    final wards = [for (var i = 1; i <= 60; i++) 'ward-$i'];
    final chunks = chunkNoticeWardIds(wards);

    expect(chunks, hasLength(3));
    for (final chunk in chunks) {
      expect(chunk.length, lessThanOrEqualTo(maxNoticeWardIdsPerQuery));
    }
    expect(chunks.expand((chunk) => chunk), wards);
  });

  test('duplicate ward ids are dropped before chunking', () {
    final chunks = chunkNoticeWardIds(
      const ['ward-1', 'ward-1', 'ward-2'],
    );

    expect(chunks, [
      ['ward-1', 'ward-2'],
    ]);
  });
}
