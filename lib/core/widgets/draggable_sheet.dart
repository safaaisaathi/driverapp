import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// DraggableSheet — bottom sheet on M1 (Map shell)
/// DESIGN.md Section 3.3 / 4.11
/// Radius 32 top, surface, elev3, grab handle 40x4 borderStrong
/// Snap points: collapsed 0.22, default 0.36, expanded 0.88
/// Content order: ContourCard -> primary actions -> secondary cards
/// Sheet bottom padding includes nav height + 16 so content never covered by nav
class DraggableSheet extends StatefulWidget {
  const DraggableSheet({
    super.key,
    required this.child,
    this.initialSize = 0.36,
    this.snapPoints = const [0.22, 0.36, 0.88],
    this.minHeight,
    this.maxHeight,
    this.onSizeChanged,
    this.navHeight = 80, // driver default
    this.enableDrag = true,
  });

  final Widget child;
  final double initialSize;
  final List<double> snapPoints;
  final double? minHeight;
  final double? maxHeight;
  final ValueChanged<double>? onSizeChanged;
  final double navHeight;
  final bool enableDrag;

  @override
  State<DraggableSheet> createState() => _DraggableSheetState();
}

class _DraggableSheetState extends State<DraggableSheet> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _currentSize = 0;
  double _dragStartSize = 0;
  double _dragStartY = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _currentSize = widget.initialSize.clamp(widget.snapPoints.first, widget.snapPoints.last);

    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    )..addListener(() {
        setState(() {
          _currentSize = _animation.value;
        });
      });
    _animation = Tween(begin: _currentSize, end: _currentSize).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.standard),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _snapTo(double target) {
    final clamped = target.clamp(widget.snapPoints.first, widget.snapPoints.last);
    _controller.animateTo(clamped);
    _currentSize = clamped;
    widget.onSizeChanged?.call(clamped);
  }

  void _onDragStart(DragStartDetails details) {
    if (!widget.enableDrag) return;
    _dragStartSize = _currentSize;
    _dragStartY = details.globalPosition.dy;
    _isDragging = true;
    _controller.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || !widget.enableDrag) return;
    final screenHeight = MediaQuery.of(context).size.height;
    final delta = (_dragStartY - details.globalPosition.dy) / screenHeight;
    _currentSize = (_dragStartSize + delta).clamp(widget.snapPoints.first, widget.snapPoints.last);
    setState(() {});
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging || !widget.enableDrag) return;
    _isDragging = false;

    // Find nearest snap point
    double nearest = widget.snapPoints.first;
    double minDist = double.infinity;
    for (final snap in widget.snapPoints) {
      final dist = (_currentSize - snap).abs();
      if (dist < minDist) {
        minDist = dist;
        nearest = snap;
      }
    }
    _snapTo(nearest);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = screenHeight * _currentSize;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onVerticalDragStart: _onDragStart,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        behavior: HitTestBehavior.translucent,
        child: AnimatedContainer(
          duration: _isDragging ? Duration.zero : AppMotion.slow,
          curve: AppMotion.standard,
          height: sheetHeight + widget.navHeight + AppSpace.lg,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
            boxShadow: Theme.of(context).brightness == Brightness.dark
                ? AppElevation.elev3Dark
                : AppElevation.elev3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(top: AppSpace.md, bottom: AppSpace.sm),
                decoration: BoxDecoration(
                  color: c.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpace.cardPad,
                    0,
                    AppSpace.cardPad,
                    widget.navHeight + AppSpace.lg,
                  ),
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sheet snap point enum for semantic use
enum SheetSnap { collapsed, default_, expanded }

extension SheetSnapExt on SheetSnap {
  double get fraction => switch (this) {
    SheetSnap.collapsed => 0.22,
    SheetSnap.default_ => 0.36,
    SheetSnap.expanded => 0.88,
  };
}