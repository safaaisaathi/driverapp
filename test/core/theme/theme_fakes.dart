/// Test fakes for the theme-choice seam (wireframe WF-21).
library;

import 'package:driverapp/core/theme/theme_mode_controller.dart';

/// In-memory [ThemeStore] standing in for SharedPreferences.
final class InMemoryThemeStore implements ThemeStore {
  final Map<String, String?> values = {};

  @override
  Future<String?> read() async => values[themeModePrefKey];

  @override
  Future<void> write(String? value) => Future<void>.sync(() {
        values[themeModePrefKey] = value;
      });

  /// Convenience getter for assertions on what got persisted.
  String? get stored => values[themeModePrefKey];
}
