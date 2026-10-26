import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the app's bundled Noto fonts for the entire test run.
///
/// Flutter's default test font (Ahem) draws every glyph as a full
/// font-size square — every overflow/width assertion against real copy
/// becomes a false positive (the GlassBar overflowed 55px in tests while
/// fitting fine on the real device). With the real faces registered here,
/// widget tests measure actual text metrics — the fonts tests use are the
/// fonts the driver sees.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sans = FontLoader('NotoSans')
    ..addFont(rootBundle.load('assets/fonts/NotoSans.ttf'));
  await sans.load();
  final gujarati = FontLoader('NotoSansGujarati')
    ..addFont(rootBundle.load('assets/fonts/NotoSansGujarati.ttf'));
  await gujarati.load();
  await testMain();
}
