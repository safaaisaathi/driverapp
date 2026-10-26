/// Binny — the Safai Sathi mascot (docs/DESIGN.md §4.20).
///
/// The ONLY mascot widget. Assets are the licensed SVGs in
/// `assets/mascot/`, used unchanged (rule D-14). Appears only on splash,
/// empty and success screens (D-06) — never on error or destructive
/// screens. One Binny per screen. Bob: ±6 dp over `dur.ambient` (2400 ms),
/// disabled when the OS requests reduced motion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum BinnyPose { wave, wait, celebrate, sleep }

class BinnyView extends StatefulWidget {
  const BinnyView({
    super.key,
    required this.pose,
    this.size = 160,
    this.label,
  });

  final BinnyPose pose;
  final double size;

  /// Set for informational use (reads with Semantics); when [label] is null
  /// the image is decorative and excluded from the semantics tree.
  final String? label;

  @override
  State<BinnyView> createState() => _BinnyViewState();
}

class _BinnyViewState extends State<BinnyView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.of(context).disableAnimations ? _c.stop() : _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = SvgPicture.asset(
      'assets/mascot/binny-${widget.pose.name}.svg',
      height: widget.size,
      semanticsLabel: widget.label,
    );
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, -6 * Curves.easeInOut.transform(_c.value)),
        child: child,
      ),
      child: widget.label == null ? ExcludeSemantics(child: img) : img,
    );
  }
}
