/// Splash — the app's launch face (first thing visible, no API involved).
///
/// Binny waves (his design-sanctioned splash pose, D-06), the app title
/// and tagline sit under him, and after a short calm hold the Welcome
/// screen takes over. Taps skip the hold — never hold a driver hostage.
/// Fully local: the Firebase bootstrap runs behind the scenes the whole
/// time and is NOT awaited here.
///
/// DESIGN.md §9.1: brandMid background, Binny wave 220, display title,
/// body tagline, fade+slide transition to Welcome (dur.base 200ms).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  void _finish(BuildContext context) {
    if (!mounted) return;
    _timer?.cancel();
    // Animate out then navigate
    _animationController.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            pageBuilder: (_, __, ___) => const WelcomeScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 200),
          ),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();

    _timer = Timer(const Duration(milliseconds: 1600), () {
      if (widget.onSplashDone == null && mounted) _finish(context);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.brandMid,
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
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const BinnyView(pose: BinnyPose.wave, size: 220),
                    const SizedBox(height: AppSpace.xl),
                    Text(
                      l10n.appTitle,
                      style: context.text.display.copyWith(
                        color: c.onBrand,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      l10n.splashTagline,
                      style: context.text.body.copyWith(
                        color: c.onBrand.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
