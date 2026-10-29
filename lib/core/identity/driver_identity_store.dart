/// Driver identity persistence seam (ticket 3, PRD-2 §0.16): where the
/// device-local `setupDone` flag and the last confirmed driver code live
/// on the phone.
///
/// The keys and values are app-owned — NOT contract constants: no backend
/// surface (0.2 / 0.16) ever reads them. The store stays DUMB: it stores
/// a bool and a string verbatim; code-format validation is the flow
/// layer's job (when the code is used), and a stale code falls back at
/// fetch time (ticket 5). Same seam pattern as the locale preferences
/// (`lib/core/l10n/locale_preferences.dart`); `shared_preferences`
/// arrives with this app via the locale ticket's dependency.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// App-owned SharedPreferences key for the one-time setup flag.
/// Absent/false both mean "fresh device".
const String driverSetupDoneKey = 'driverapp.identity.setupDone';

/// App-owned SharedPreferences key for the last confirmed driver code.
/// Absent means "no driver remembered on this phone".
const String driverCodeKey = 'driverapp.identity.driverCode';

/// Storage seam for the driver identity (setup-done + remembered code).
///
/// Production uses [SharedPreferencesDriverIdentityStore]; tests inject
/// an in-memory fake, so no test ever reaches the platform channels.
/// Reads NEVER throw: a value that is absent or of the wrong type reads
/// as null (the controller degrades that to fresh-device).
abstract interface class DriverIdentityStore {
  /// The stored setup-done flag, or null when absent/corrupt.
  Future<bool?> readSetupDone();

  /// The stored driver code, or null when absent/corrupt.
  Future<String?> readDriverCode();

  /// Persists the setup-done flag (only ever written `true` today).
  Future<void> writeSetupDone(bool value);

  /// Persists the driver code (null clears it).
  Future<void> writeDriverCode(String? value);
}

/// SharedPreferences-backed store (the real code path).
///
/// Reads go through [SharedPreferences.get] (the untyped accessor) and
/// type-check the result, so a corrupt entry (wrong type under the key)
/// degrades to null instead of throwing a cast error.
final class SharedPreferencesDriverIdentityStore
    implements DriverIdentityStore {
  const SharedPreferencesDriverIdentityStore();

  @override
  Future<bool?> readSetupDone() async {
    final value =
        (await SharedPreferences.getInstance()).get(driverSetupDoneKey);
    return value is bool ? value : null;
  }

  @override
  Future<String?> readDriverCode() async {
    final value = (await SharedPreferences.getInstance()).get(driverCodeKey);
    return value is String ? value : null;
  }

  @override
  Future<void> writeSetupDone(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(driverSetupDoneKey, value);
  }

  @override
  Future<void> writeDriverCode(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(driverCodeKey);
    } else {
      await prefs.setString(driverCodeKey, value);
    }
  }
}
