/// Splash — the app's launch face (first thing visible, no API involved).
///
/// Binny waves (his design-sanctioned splash pose, D-06), the app title
/// and tagline sit under him, and after a short calm hold the Welcome
/// screen takes over. Taps skip the hold — never hold a driver hostage.
/// Fully local: the Firebase bootstrap runs behind the scenes the whole
/// time and is NOT awaited here.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/binny.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onSplashDone});

  /// Navigation seam for tests.
  final void Function(BuildContext context)? onSplashDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  void _finish(BuildContext context) {
    if (!mounted) return;
    _timer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
    );
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1600), () {
      if (widget.onSplashDone == null && mounted) _finish(context);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      body: GestureDetector(
        // A tap skips the hold; a busy driver never waits.
        onTap: () {
          if (widget.onSplashDone != null) {
            widget.onSplashDone!(context);
          } else {
            _finish(context);
          }
        },
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const BinnyView(pose: BinnyPose.wave, size: 180),
                const SizedBox(height: AppSpace.xl),
                Text(
                  l10n.appTitle,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  l10n.splashTagline,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
