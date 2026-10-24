/// Test fakes for the F-D10 locale seam (ticket 13).
///
/// The [LocaleStore] seam is SharedPreferences-backed in real code;
/// these fakes keep every test off the platform channels.
library;

import 'package:driverapp/core/l10n/locale_preferences.dart';

/// In-memory [LocaleStore] standing in for SharedPreferences.
///
/// The backing map can be shared between fresh containers, so a test can
/// simulate an app restart without any process or platform trickery.
final class InMemoryLocaleStore implements LocaleStore {
  final Map<String, String?> values = {};

  @override
  Future<String?> read() async => values[localePrefKey];

  @override
  Future<void> write(String? value) => Future<void>.sync(() {
        values[localePrefKey] = value;
      });

  /// Convenience getter for assertions on what got persisted.
  String? get stored => values[localePrefKey];
}

/// [LocaleStore] that delays [read] — simulates a slow restore so tests
/// can race an explicit choice against the pending restore.
final class DelayedLocaleStore implements LocaleStore {
  DelayedLocaleStore(this.inner, this.delay);

  final LocaleStore inner;
  final Duration delay;

  @override
  Future<String?> read() async {
    await Future<void>.delayed(delay);
    return inner.read();
  }

  @override
  Future<void> write(String? value) => inner.write(value);
}
