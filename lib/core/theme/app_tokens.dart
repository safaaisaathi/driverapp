import 'package:flutter/material.dart';

/// Space tokens (4 dp grid)
class AppSpace {
  static const double unit = 8; // PRD spacing.unit
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 20, xxl = 24, xxxl = 32, huge = 40;
  static const double page = 20; // horizontal page padding
  static const double cardGap = 12, cardPad = 20, sectionGap = 24;
}

/// Radius tokens
class AppRadius {
  static const double md = 12; // PRD radius.md: map bubbles, small tags
  static const double control = 20; // inputs, small cards
  static const double card = 28; // cards, contour card
  static const double sheet = 32; // top corners of sheets
  static const double pill = 999; // buttons, chips, nav, glass bar
}

/// Size tokens
class AppSize {
  static const double touchMin = 48, touchDriver = 56;
  static const double buttonUser = 56, buttonDriver = 64; // pill buttons
  static const double bigAction = 72; // driver "Mark Ward Done"
  static const double iconButton = 48, iconButtonDriver = 56;
  static const double navHeight = 72, navItem = 56, navHeightDriver = 80, navItemDriver = 64;
  static const double glassBarHeight = 64, glassBarInset = 16;
  static const double icon = 24, iconSmall = 20;
  static const double vanMarker = 44, pinWidth = 40, pinHeight = 52, markerHit = 48;
  static const double thumb = 72; // complaint thumbnail

  // Driver-only additions (DESIGN-driver-app.md §2.3)
  static const double permissionIconCircle = 96; // [est] neutral-icon circle
  static const double codeBox = 56; // code-entry cell, XX-0000 box (§2.3)
}

/// Elevation tokens (BoxShadow only, never Material elevation tint)
class AppElevation {
  static const List<BoxShadow> elev0 = [];

  static const List<BoxShadow> elev1 = [
    BoxShadow(
      color: Color(0x0F111A14), // black 6%
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> elev1Dark = [
    BoxShadow(
      color: Color(0x66000000), // dark: 40%
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> elev2 = [
    BoxShadow(
      color: Color(0x1E111A14), // black 12%
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> elev2Dark = [
    BoxShadow(
      color: Color(0x8C000000), // dark: 55%
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> elev3 = [
    BoxShadow(
      color: Color(0x29111A14), // black 16%
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  static const List<BoxShadow> elev3Dark = [
    BoxShadow(
      color: Color(0x99000000), // dark: 60%
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  // Glass bar: surface at 82% opacity + BackdropFilter blur sigma 16
  // Opacity MUST NOT go below 80% (text legibility over the map)
}

/// Motion tokens
class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
  static const Duration ambient = Duration(milliseconds: 2400); // pulse ring, shimmer
  static const Curve standard = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
}

/// Breakpoint tokens
class AppBreakpoint {
  static const double compact = 360;
  static const double large = 600;
}