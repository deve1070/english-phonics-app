import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Spacing scale — 4pt base grid
abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}

/// Corner radii.
///
/// Pulled in from the old 36/999 scale. Everything being a pill is a large
/// part of what made the previous UI read as generic; these are chunky but
/// still recognisably rectangular, like printed cards or wooden tiles.
/// [full] survives only for genuinely circular elements.
abstract class AppRadius {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 26;
  static const double full = 999;
}

/// Border weights. Interactive surfaces carry a visible ink outline, which
/// gives them a sticker/board-game quality and makes the tappable area
/// unambiguous — useful for children and for anyone with low vision.
abstract class AppBorders {
  static const double hairline = 1.5;
  static const double standard = 2.5;
  static const double heavy = 3.5;

  static Border ink({double width = standard, Color? color}) =>
      Border.all(color: color ?? AppColors.border, width: width);
}

/// Hard offset shadows — solid colour, **zero blur**.
///
/// Two reasons, and they happen to agree:
///
/// 1. Soft blurred shadows under everything are the visual signature of
///    generated UI. A hard offset instead reads as cut paper or a stacked
///    board-game piece, which suits a children's app far better.
/// 2. Blur is genuinely expensive to rasterise. On the low-end Android
///    hardware this app is most likely to run on, a screen full of blurred
///    shadows is a real source of jank; an offset solid rectangle is
///    nearly free.
///
/// Depth is expressed by *offset distance*, not by softness: the further a
/// surface sits from the page, the further its shadow is displaced.
abstract class AppShadows {
  static const List<BoxShadow> flat = [];

  /// Resting surfaces: cards, tiles, list rows.
  static const List<BoxShadow> card = [
    BoxShadow(color: AppColors.shadow, blurRadius: 0, offset: Offset(0, 3)),
  ];

  /// Interactive surfaces at rest. Deeper, so pressing them can visibly
  /// collapse the gap.
  static const List<BoxShadow> raised = [
    BoxShadow(color: AppColors.shadow, blurRadius: 0, offset: Offset(0, 5)),
  ];

  /// The pressed state of a [raised] surface. Pair with a matching
  /// downward translation so the element appears to physically depress.
  static const List<BoxShadow> pressed = [
    BoxShadow(color: AppColors.shadow, blurRadius: 0, offset: Offset(0, 1)),
  ];

  /// Modals and anything genuinely floating above the page.
  static const List<BoxShadow> floating = [
    BoxShadow(color: AppColors.shadow, blurRadius: 0, offset: Offset(0, 8)),
  ];

  /// How far a [raised] surface travels when pressed. Kept here so the
  /// shadow and the translation can never drift out of sync.
  static const double pressTravel = 4;
}

/// Min touch target size for kids (56dp)
abstract class AppSizes {
  static const double minTouchTarget = 56;
  static const double bottomNavHeight = 72;
  static const double appBarHeight = 60;

  /// Phoneme lesson card on home
  static const double lessonCardHeight = 120;

  /// Letter tile in spelling bee
  static const double spellingTileSize = 64;

  /// Mascot on splash/onboarding
  static const double mascotHeight = 280;

  /// Stop on the journey map
  static const double journeyStop = 68;
}
