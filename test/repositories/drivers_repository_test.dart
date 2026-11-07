import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repositories.dart';
import 'package:flutter_test/flutter_test.dart';

import '../models/sample_maps.dart';
import 'fake_repositories.dart';

/// Contract tests for the driver-identity seam (0.16): code normalization,
/// the `drivers` doc shape, and the DriversRepository fetch contract. A bad
/// shape never reaches Firestore; no active-filtering happens at this seam
/// (the flow layer treats `active = false` as not-found, tickets 4/5).
void main() {
  group('normalizeDriverCode (0.16: trim, uppercase, insert dash)', () {
    test('accepts ab1234 / AB-1234 / ab-1234 and trims spaces', () {
      expect(normalizeDriverCode('ab1234'), 'AB-1234');
      expect(normalizeDriverCode('AB-1234'), 'AB-1234');
      expect(normalizeDriverCode('ab-1234'), 'AB-1234');
      expect(normalizeDriverCode('  ab1234  '), 'AB-1234');
      expect(normalizeDriverCode(' AB-1234 '), 'AB-1234');
    });

    test('rejects garbage shapes with null', () {
      expect(normalizeDriverCode(''), isNull);
      expect(normalizeDriverCode('   '), isNull);
      expect(normalizeDriverCode('abc1234'), isNull); // 3 letters
      expect(normalizeDriverCode('a1234'), isNull); // 1 letter
      expect(normalizeDriverCode('ab123'), isNull); // 3 digits
      expect(normalizeDriverCode('ab12345'), isNull); // 5 digits
      expect(normalizeDriverCode('12-1234'), isNull); // digits, not letters
      expect(normalizeDriverCode('AB_1234'), isNull); // wrong separator
      expect(normalizeDriverCode('ab 1234'), isNull); // inner space
      expect(normalizeDriverCode('AB--1234'), isNull); // double dash
      expect(normalizeDriverCode('ab-1234x'), isNull); // trailing junk
    });
  });

  group('Driver model (0.16 doc shape)', () {
    test('fromMap ∘ toMap round-trip', () {
      final model = Driver.fromMap(driverDocMap());
      final roundTrip = Driver.fromMap(model.toMap());
      expect(roundTrip, model);
      expect(model.toMap(), roundTrip.toMap());
      expect(model.id, 'AB-1234');
      expect(model.name, 'Ramesh Patel');
      expect(model.phoneMasked, '98XXXXXX10');
      expect(model.vanId, 'van-01');
      expect(model.routeId, 'route-01');
      expect(model.wardIds, const ['ward-01', 'ward-02']);
      expect(model.active, isTrue);
    });

    test('equality: same fields equal, different wardIds not', () {
      final model = Driver.fromMap(driverDocMap());
      expect(Driver.fromMap(driverDocMap()), model);
      final fewerWards = Driver.fromMap(<String, Object?>{
        ...driverDocMap(),
        'wardIds': <String>['ward-01'],
      });
      expect(fewerWards == model, isFalse);
    });
  });

  group('DriversRepository seam (FakeDriversRepository)', () {
    late FakeDriversRepository repo;
    late Driver driver;

    setUp(() {
      driver = Driver.fromMap(driverDocMap());
      repo = FakeDriversRepository([driver]);
    });

    test('implements the seam interface so ProviderScope overrides type-check',
        () {
      expect(repo, isA<DriversRepository>());
    });

    test('fetchDriver finds the driver for any accepted code variant', () async {
      expect(await repo.fetchDriver('ab1234'), driver);
      expect(await repo.fetchDriver('AB-1234'), driver);
      expect(await repo.fetchDriver(' ab-1234 '), driver);
    });

    test('fetchDriver consults the backing map with the normalized code',
        () async {
      await repo.fetchDriver('ab1234');
      expect(repo.lookups, const ['AB-1234']);
    });

    test('fetchDriver returns null (not an error) for a well-formed unknown code',
        () async {
      expect(await repo.fetchDriver('CD-9999'), isNull);
      expect(repo.lookups, const ['CD-9999']);
    });

    test(
        'a bad shape returns null without consulting the backing map '
        '(no Firestore call)', () async {
      expect(await repo.fetchDriver('garbage'), isNull);
      expect(await repo.fetchDriver('ab12'), isNull);
      expect(repo.lookups, isEmpty);
    });
  });
}
