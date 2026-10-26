import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// ContourCard — SIGNATURE component per DESIGN.md Section 4.9 (rule CL-12).
///
/// The route-progress top element of the D2 sheet (and D4 cards later):
/// brandMid fill, radius 28, ink text only, the hand-drawn contour lines
/// behind the content. Text is set by the caller — this widget owns no copy
/// (CL-21). Seed a stable value per entity (e.g. the route name hash) so the
/// contours don't jitter between rebuilds.
class ContourCard extends StatelessWidget {
  const ContourCard({
    super.key,
    required this.child,
    this.seed = 0,
    this.lines = 9,
    this.minHeight = 160,
  });

  final Widget child;
  final int seed;
  final int lines;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      container: true,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        padding: EdgeInsets.all(AppSpace.cardPad),
        decoration: BoxDecoration(
          color: c.brandMid,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        // The contour painter's rings span up to 0.9 x the card's longest
        // side: without a clip they paint past the rounded card across the
        // whole window (a bare Flutter canvas has no bounds), ghosting green
        // rings over the map and every layer under this stack.
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            // Contour lines behind the content. Positioned.fill keeps the
            // painter bounded: a bare CustomPaint hugs the child and crashes
            // with "infinite size" inside shrinkWrap columns.
            Positioned.fill(
              child: CustomPaint(
                painter: ContourPainter(seed: seed, lines: lines),
              ),
            ),
            // Content — the sizing child (brandMid + ink text per design,
            // the caller styles its own Text against c.textPrimary).
            child,
          ],
        ),
      ),
    );
  }
}

/// ContourPainter — draws the signature contour lines.
class ContourPainter extends CustomPainter {
  ContourPainter({required this.seed, this.lines = 9});
  final int seed;
  final int lines;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final cx = size.width * (0.35 + rnd.nextDouble() * 0.3);
    final cy = size.height * (0.35 + rnd.nextDouble() * 0.3);
    final p1 = rnd.nextDouble() * math.pi * 2;
    final p2 = rnd.nextDouble() * math.pi * 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..color = const Color(0xFF1B7A3F).withValues(alpha: 0.35);
    final maxR = size.longestSide * 0.9;
    for (var i = 1; i <= lines; i++) {
      final r = maxR * i / lines;
      final path = Path();
      for (var a = 0; a <= 360; a += 6) {
        final t = a * math.pi / 180;
        final rr =
            r * (1 + 0.10 * math.sin(2 * t + p1) + 0.06 * math.sin(3 * t + p2));
        final x = cx + rr * math.cos(t);
        final y = cy + rr * math.sin(t) * 0.75;
        a == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(ContourPainter o) => o.seed != seed || o.lines != lines;
}
