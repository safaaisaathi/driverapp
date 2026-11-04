/// The stable per-install id `bindDeviceToVan` needs.
///
/// The callable's note is explicit: this is a stable per-install uuid, NOT a
/// per-launch value. A per-launch id would make every launch look like a
/// second phone and the van would read as already claimed.
library;

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage seam so tests never touch platform channels.
abstract interface class InstallIdStore {
  /// The stored id, created once on first use.
  Future<String> readOrCreate();
}

/// The preferences key. Never renamed: a rename re-binds every phone.
const String installIdKey = 'installId';

/// `SharedPreferences`-backed store.
final class SharedPreferencesInstallIdStore implements InstallIdStore {
  const SharedPreferencesInstallIdStore();

  @override
  Future<String> readOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(installIdKey);
    if (stored != null && stored.isNotEmpty) return stored;
    final created = newInstallId();
    await prefs.setString(installIdKey, created);
    return created;
  }
}

/// A random 32-hex-character id. No uuid dependency: the callable only needs
/// a stable opaque string.
String newInstallId([Random? random]) {
  final source = random ?? Random.secure();
  final buffer = StringBuffer();
  for (var index = 0; index < 16; index++) {
    buffer.write(source.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

/// The install id seam (overridden with a fixed id in tests).
final installIdStoreProvider = Provider<InstallIdStore>(
  (ref) => const SharedPreferencesInstallIdStore(),
);
