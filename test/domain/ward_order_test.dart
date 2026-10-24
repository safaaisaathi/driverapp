import 'package:driverapp/core/domain/ward_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const w1 = 'ward_1';
  const w2 = 'ward_2';
  const w3 = 'ward_3';
  const route = [w1, w2, w3];

  group('nextUndoneWardId', () {
    test('empty route → null', () {
      expect(nextUndoneWardId([], {}), isNull);
    });

    test('all done → null', () {
      expect(nextUndoneWardId(route, {w1, w2, w3}), isNull);
    });

    test('nothing done yet → first ward in route order', () {
      expect(nextUndoneWardId(route, {}), w1);
    });

    test('normal progress: next undone ward is in route order', () {
      expect(nextUndoneWardId(route, {w1}), w2);
      expect(nextUndoneWardId(route, {w1, w2}), w3);
    });

    test('done set not in order: still follows route order, not done order',
        () {
      expect(nextUndoneWardId(route, {w2}), w1);
      expect(nextUndoneWardId(route, {w3}), w1);
    });

    test('done set containing an unknown ward id is simply ignored', () {
      expect(nextUndoneWardId(route, {'not_on_route'}), w1);
    });

    test('last ward done first → first ward is still next', () {
      expect(nextUndoneWardId(route, {w3, w1}), w2);
    });
  });

  group('outOfOrderWardIds', () {
    test('empty route → empty', () {
      expect(outOfOrderWardIds([], {}), isEmpty);
    });

    test('all done → empty', () {
      expect(outOfOrderWardIds(route, {w1, w2, w3}), isEmpty);
    });

    test('nothing done → every ward except the first is out of order', () {
      expect(outOfOrderWardIds(route, {}), [w2, w3]);
    });

    test('done-first-remaining: only the remaining after next', () {
      expect(outOfOrderWardIds(route, {w1}), [w3]);
      expect(outOfOrderWardIds(route, {w1, w2}), isEmpty);
    });

    test('keeps route order for the out-of-order list', () {
      // done = {w2}: next undone is w1, remaining undone w3 listed after it.
      expect(outOfOrderWardIds([w1, w2, w3], {w2}), [w3]);
    });

    test('out-of-order list never includes the next undone ward or done ones',
        () {
      final list = outOfOrderWardIds(route, {w1});
      expect(list, [w3]);
      expect(list.contains(nextUndoneWardId(route, {w1})), isFalse);
    });
  });

  group('positionOfWard', () {
    test('finds 0-based positions in order', () {
      expect(positionOfWard(route, w1), 0);
      expect(positionOfWard(route, w2), 1);
      expect(positionOfWard(route, w3), 2);
    });

    test('ward not on route → null', () {
      expect(positionOfWard(route, 'other'), isNull);
    });

    test('works on empty route', () {
      expect(positionOfWard([], w1), isNull);
    });
  });
}
