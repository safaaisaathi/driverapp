/// Skeleton loaders — content-shape placeholders while gated data loads.
///
/// The DESIGN.md no-blank-screens rule: a loading state shows the SHAPE of
/// the content that is arriving, not a bare spinner. Boxes pulse between a
/// muted floor and full surface contrast over `dur.ambient`; disabled to a
/// static half-tone when the OS asks for reduced motion.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius,
  });

  final double width;
  final double height;
  final double? radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: hold the mid-contrast frame, no pulsing.
    MediaQuery.of(context).disableAnimations
        ? _c.stop()
        : _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_c),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: colors.brandMid,
          borderRadius:
              BorderRadius.circular(widget.radius ?? AppRadius.card),
        ),
      ),
    );
  }
}

/// One van-card placeholder: the list row shape the D1 picker renders
/// (icon dot, title line, subtitle line) — 3 stacked so the screen fills
/// the same way the real picker does.
class SkeletonVanCard extends StatelessWidget {
  const SkeletonVanCard({super.key, this.height = 96});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.unit),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            SkeletonBox(width: 48, height: 48, radius: 24),
            const SizedBox(width: AppSpace.unit * 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SkeletonBox(width: 180, height: 20),
                  const SizedBox(height: AppSpace.unit),
                  const SkeletonBox(width: 240, height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
