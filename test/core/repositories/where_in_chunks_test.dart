/// B-06: Firestore caps one `in` / `not-in` clause at 30 values. These tests
/// pin the chunk boundary and the order.
library;

import 'package:driverapp/core/repositories/where_in_chunks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an empty list yields no query', () {
    expect(chunkWhereIn<String>(const []), isEmpty);
  });

  test('exactly the cap stays one chunk', () {
    final ids = [for (var i = 0; i < 30; i++) 'w$i'];
    final chunks = chunkWhereIn(ids);

    expect(chunks, hasLength(1));
    expect(chunks.single, ids);
  });

  test('one over the cap splits 30 + 1', () {
    final ids = [for (var i = 0; i < 31; i++) 'w$i'];
    final chunks = chunkWhereIn(ids);

    expect(chunks, hasLength(2));
    expect(chunks[0], ids.sublist(0, 30));
    expect(chunks[1], ['w30']);
  });

  test('every value appears exactly once, in order', () {
    final ids = [for (var i = 0; i < 65; i++) 'w$i'];
    final chunks = chunkWhereIn(ids);

    expect(chunks.map((chunk) => chunk.length), [30, 30, 5]);
    expect(chunks.expand((chunk) => chunk).toList(), ids);
  });
}
