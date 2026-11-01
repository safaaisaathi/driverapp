/// Splash — the app's launch face (first thing visible, no API involved).
///
/// A pure auto-routing loading screen: brand background, title, tagline and
/// a neutral icon (mascot-free, [removed-T8]). No buttons, no tap-to-skip
/// — zero interactive elements.
///
/// It holds for a short brand moment and advances AUTOMATICALLY once the
/// bootstrap answered (ready OR degraded): a failed boot still advances,
/// and a boot that never answers is cut off by a hard cap — the splash
/// never hangs and never keeps a driver waiting on a dead Firebase.
///
/// The destination follows the device-local `setupDone` flag read from the
/// identity controller: setup-done → CodeStartScreen; fresh device →
/// WelcomeScreen. `main()` awaits `ensureRestored()` before `runApp`, so
/// the first frame already knows the flag — deterministic, no flash. A
/// `onSplashDone` seam is kept for tests; production navigates
/// automatically.
///
/// DESIGN.md §9.1: brandMid background, neutral icon 220 in a brandSoft
/// circle, display title, body tagline, fade transition to the destination
/// (dur.base 200ms).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/firebase_bootstrap.dart';
import '../../../core/identity/driver_identity_controller.dart'
    show driverIdentityControllerProvider;
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../shift_start/ui/code_start_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, this.onSplashDone});

  /// Navigation seam for tests. Fires when the splash auto-advances; when
  /// null the splash navigates itself.
  final void Function(BuildContext context)? onSplashDone;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  /// The brand moment: the splash is on screen at least this long, so a
  /// fast boot never turns it into a flash.
  static const Duration _brandHold = Duration(milliseconds: 1000);

  /// The hard cap: a bootstrap that never answers must not hold the driver
  /// on the splash. Short on purpose — a dead Firebase must not cost the
  /// driver more than a second and a half.
  static const Duration _maxHold = Duration(milliseconds: 1600);

  Timer? _brandTimer;
  Timer? _maxTimer;
  bool _brandHeld = false;
  bool _bootAnswered = false;
  bool _maxHoldElapsed = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _brandTimer = Timer(_brandHold, () {
      _brandHeld = true;
      _tryAdvance();
    });
    _maxTimer = Timer(_maxHold, () {
      _maxHoldElapsed = true;
      _tryAdvance();
    });
  }

  @override
  void dispose() {
    _brandTimer?.cancel();
    _maxTimer?.cancel();
    super.dispose();
  }

  /// Advance when the brand moment is over AND the boot answered (or the
  /// hard cap fired).
  void _tryAdvance() {
    if (_navigating || !mounted) return;
    if (!_brandHeld) return;
    if (!_bootAnswered && !_maxHoldElapsed) return;
    _advance();
  }

  void _advance() {
    _navigating = true;
    _brandTimer?.cancel();
    _maxTimer?.cancel();

    final setupDone = ref.read(driverIdentityControllerProvider).isSetupDone;

    if (widget.onSplashDone != null) {
      widget.onSplashDone!(context);
      return;
    }

    final destination =
        setupDone ? const CodeStartScreen() : const WelcomeScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => destination,
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The boot status is observed, never awaited: the splash advances when
    // it answers (ready or degraded) and the hard cap covers a silent boot.
    final boot = ref.watch(bootstrapProvider);
    if (boot is! BootstrapPending && !_bootAnswered) {
      _bootAnswered = true;
      // The status can change while the frame is building, so the advance
      // waits for the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryAdvance();
      });
    }

    final l10n = AppLocalizations.of(context)!;
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.brandMid,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: c.brandSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.directions_outlined, size: 160, color: c.brand),
              ),
              const SizedBox(height: AppSpace.xl),
              Text(
                l10n.appTitle,
                style: context.text.display.copyWith(color: c.onBrand),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                l10n.splashTagline,
                style: context.text.body.copyWith(color: c.onBrand.withValues(alpha: 0.8)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
