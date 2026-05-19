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

/// Border radius scale
abstract class AppRadius {
  static const double sm = 12;
  static const double md = 20;
  static const double lg = 28;
  static const double xl = 36;
  static const double full = 999; // pill shape
}

/// Shared box shadows
abstract class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.shadowLight,
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> button = [
    BoxShadow(
      color: AppColors.shadowMedium,
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> floating = [
    BoxShadow(
      color: AppColors.shadowMedium,
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
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

  /// Mascot image on splash/onboarding
  static const double mascotHeight = 280;
}
