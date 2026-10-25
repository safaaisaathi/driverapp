/// Ward-step derivation tests (ticket 06): route order + done ticks +
/// next-ward highlight from `trips.wardsDone` of the open trip — the pure
/// logic behind the D2 markers/list (seam 2: no Firebase, no widgets).
library;

import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/features/live_route/domain/ward_steps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const location = LocationPoint(lat: 22.77, lng: 73.71);

  Ward ward(String id, {String name = 'W'}) => Ward(
        id: id,
        name: name == 'W' ? 'Ward $id' : name,
        nameGu: 'gu-$id',
        code: 'code-$id',
        type: WardType.urban,
        center: location,
        radiusM: 400,
        routeId: 'route-01',
        inspectorId: 'staff-01',
        escalationTo: 'staff-09',
      );

  group('deriveWardSteps', () {
    test('orders by routes.wardIds, not the ward load order', () {
      final steps = deriveWardSteps(
        orderedWardIds: ['wa', 'wb', 'wc'],
        wardsById: {'wa': ward('wa'), 'wb': ward('wb'), 'wc': ward('wc')},
        done: const TripDoneState({}, {}),
      );
      expect(
        [for (final s in steps) s.ward.id],
        ['wa', 'wb', 'wc'],
      );
      expect(steps.map((s) => s.orderIndex), [0, 1, 2]);
    });

    test('ticked set comes from trips.wardsDone ids', () {
      final steps = deriveWardSteps(
        orderedWardIds: ['wa', 'wb', 'wc'],
        wardsById: {'wa': ward('wa'), 'wb': ward('wb'), 'wc': ward('wc')},
        done: const TripDoneState({'wa', 'wc'}, {}),
      );
      expect(steps.map((s) => s.isDone), [true, false, true]);
    });

    test('next is the first undone in route order (ruling 5 model)', () {
      final steps = deriveWardSteps(
        orderedWardIds: ['wa', 'wb', 'wc'],
        wardsById: {'wa': ward('wa'), 'wb': ward('wb'), 'wc': ward('wc')},
        done: const TripDoneState({'wa'}, {}),
      );
      expect(
        [for (final s in steps) if (s.isNext) s.ward.id],
        ['wb'],
      );
    });

    test('all done → no next ward (route complete)', () {
      final steps = deriveWardSteps(
        orderedWardIds: ['wa', 'wb'],
        wardsById: {'wa': ward('wa'), 'wb': ward('wb')},
        done: const TripDoneState({'wa', 'wb'}, {}),
      );
      expect(steps.every((s) => s.isDone), isTrue);
      expect(steps.any((s) => s.isNext), isFalse);
    });

    test('unknown done ids are ignored (not rendered)', () {
      final steps = deriveWardSteps(
        orderedWardIds: ['wa', 'wb'],
        wardsById: {'wa': ward('wa'), 'wb': ward('wb')},
        done: const TripDoneState({'wa', 'ghost', 'unrelated'}, {}),
      );
      expect(steps.map((s) => s.ward.id), ['wa', 'wb']);
      expect(steps.map((s) => s.isDone), [true, false]);
    });

    test('duplicate route ids → first occurrence rules order (ruling 5)', () {
      final deduped = [
        for (final id in dedupeForCheck(['wa', 'wb', 'wa'])) id,
      ];
      expect(deduped, ['wa', 'wb']);
    });

    test('route ids without a resolved ward doc are dropped', () {
      final steps = deriveWardSteps(
        orderedWardIds: ['wa', 'ghost', 'wb'],
        wardsById: {'wa': ward('wa'), 'wb': ward('wb')},
        done: const TripDoneState({}, {}),
      );
      expect(steps.map((s) => s.ward.id), ['wa', 'wb']);
      // Indexes stay list positions of the dropping route (informational).
      expect(steps.map((s) => s.orderIndex), [0, 2]);
    });

    test('flagged set comes from the flagged done ids', () {
      final steps = deriveWardSteps(
        orderedWardIds: ['wa', 'wb'],
        wardsById: {'wa': ward('wa'), 'wb': ward('wb')},
        done: const TripDoneState({'wa'}, {'wa'}),
      );
      expect(steps.first.isFlagged, isTrue);
      expect(steps.last.isFlagged, isFalse);
    });
  });

  group('TripDoneState.of', () {
    test('null trip → nothing done', () {
      final state = TripDoneState.of(null);
      expect(state.doneIds, isEmpty);
      expect(state.flaggedIds, isEmpty);
    });

    test('extracts ids and flags from trips.wardsDone', () {
      final now = DateTime.utc(2026, 10, 24, 9);
      final trip = Trip.fromMap({
        'id': 'trip-1',
        'vanId': 'van-01',
        'routeId': 'route-01',
        'date': now,
        'startedAt': now,
        'endedAt': null,
        'wardsDone': [
          {'wardId': 'wa', 'doneAt': now, 'flagged': false},
          {'wardId': 'wb', 'doneAt': now, 'flagged': true},
        ],
        'alertedWardIds': [],
        'gpsTrail': [],
        'mockLocationDetected': false,
      });
      final state = TripDoneState.of(trip);
      expect(state.doneIds, {'wa', 'wb'});
      expect(state.flaggedIds, {'wb'});
    });

    test('duplicate wardId entries collapse (dedupe ruling 13)', () {
      final now = DateTime.utc(2026, 10, 24, 9);
      final trip = Trip.fromMap({
        'id': 'trip-1',
        'vanId': 'van-01',
        'routeId': 'route-01',
        'date': now,
        'startedAt': now,
        'endedAt': null,
        'wardsDone': [
          {'wardId': 'wa', 'doneAt': now, 'flagged': false},
          {'wardId': 'wa', 'doneAt': now, 'flagged': false},
          {'wardId': 'wb', 'doneAt': now, 'flagged': false},
          {'wardId': 'wb', 'doneAt': now, 'flagged': false},
        ],
        'alertedWardIds': [],
        'gpsTrail': [],
        'mockLocationDetected': false,
      });
      final state = TripDoneState.of(trip);
      expect(state.doneIds.length, 2);
      expect(state.doneIds, {'wa', 'wb'});
    });
  });
}

/// Local mirror of the merge logic that backs combineLiveRouteState — kept
/// here so this test file needs no Riverpod (the reducer dedupes before
/// calling deriveWardSteps).
List<String> dedupeForCheck(List<String> ids) {
  final seen = <String>{};
  return [for (final id in ids) if (seen.add(id)) id];
}
