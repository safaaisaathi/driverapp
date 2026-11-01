/// Test fakes for the driver-identity persistence seam (ticket 3).
///
/// The [DriverIdentityStore] seam is SharedPreferences-backed in real
/// code; these fakes keep every test off the platform channels.
library;

import 'package:driverapp/core/identity/driver_identity_store.dart';

/// In-memory [DriverIdentityStore] standing in for SharedPreferences.
///
/// The backing map holds RAW values (not just the seam's types), so a
/// test can plant corrupt entries — a non-bool under the setup-done key,
/// a non-string under the code key — and pin the degrade-don't-throw
/// contract. It can be shared between fresh containers, so a test can
/// simulate an app restart without any process or platform trickery.
final class InMemoryDriverIdentityStore implements DriverIdentityStore {
  final Map<String, Object?> values = {};

  @override
  Future<bool?> readSetupDone() async {
    final value = values[driverSetupDoneKey];
    return value is bool ? value : null;
  }

  @override
  Future<String?> readDriverCode() async {
    final value = values[driverCodeKey];
    return value is String ? value : null;
  }

  @override
  Future<void> writeSetupDone(bool value) => Future<void>.sync(() {
        values[driverSetupDoneKey] = value;
      });

  @override
  Future<void> writeDriverCode(String? value) => Future<void>.sync(() {
        if (value == null) {
          values.remove(driverCodeKey);
        } else {
          values[driverCodeKey] = value;
        }
      });

  /// What actually sits under the setup-done key (null = absent).
  bool? get storedSetupDone =>
      values[driverSetupDoneKey] is bool ? values[driverSetupDoneKey] as bool : null;

  /// What actually sits under the code key (null = absent).
  String? get storedDriverCode =>
      values[driverCodeKey] is String ? values[driverCodeKey] as String : null;
}

/// [DriverIdentityStore] that delays both reads — simulates a slow
/// restore so tests can race an explicit driver action against the
/// pending restore.
final class DelayedDriverIdentityStore implements DriverIdentityStore {
  DelayedDriverIdentityStore(this.inner, this.delay);

  final DriverIdentityStore inner;
  final Duration delay;

  @override
  Future<bool?> readSetupDone() async {
    await Future<void>.delayed(delay);
    return inner.readSetupDone();
  }

  @override
  Future<String?> readDriverCode() async {
    await Future<void>.delayed(delay);
    return inner.readDriverCode();
  }

  @override
  Future<void> writeSetupDone(bool value) => inner.writeSetupDone(value);

  @override
  Future<void> writeDriverCode(String? value) => inner.writeDriverCode(value);
}
