/// F-D10 persistence seam (ticket 13): where the driver's language
/// choice lives on the phone.
///
/// The key and stored codes are app-owned — NOT contract constants: no
/// backend surface (0.2 / 0.13) ever reads them. `shared_preferences`
/// is the first key-value persistence this app adds (the first-launch
/// flag uses Hive instead, ticket 02); it arrives with this ticket.
library;

import 'package:flutter/material.dart' show Locale;
import 'package:shared_preferences/shared_preferences.dart';

/// App-owned SharedPreferences key for the driver's language choice.
/// Stored values are the language codes `'en'` / `'gu'`; a missing
/// value means "no choice made" (system default — English during
/// development per the grilled decision, spec Implementation Decisions).
const String localePrefKey = 'driverapp.locale';

/// Storage seam for the language choice.
///
/// Production uses [SharedPreferencesLocaleStore]; tests inject an
/// in-memory fake, so no test ever reaches the platform channels.
abstract interface class LocaleStore {
  /// The stored choice, or null when no valid choice was made yet.
  Future<String?> read();

  /// Persists the choice (null clears it).
  Future<void> write(String? value);
}

/// SharedPreferences-backed store (the real code path).
final class SharedPreferencesLocaleStore implements LocaleStore {
  const SharedPreferencesLocaleStore();

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(localePrefKey);

  @override
  Future<void> write(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(localePrefKey);
    } else {
      await prefs.setString(localePrefKey, value);
    }
  }
}

/// Stored code → [Locale]: only the two shipped languages count;
/// corrupt/foreign values read as "no choice" and fall back to the
/// system default (English during development).
Locale? decodeStoredLocale(String? code) => switch (code) {
      'en' => const Locale('en'),
      'gu' => const Locale('gu'),
      _ => null,
    };

/// [Locale] → stored code; anything outside the shipped pair stores
/// null (= "no choice").
String? encodeStoredLocale(Locale? locale) => switch (locale?.languageCode) {
      'en' => 'en',
      'gu' => 'gu',
      _ => null,
    };
