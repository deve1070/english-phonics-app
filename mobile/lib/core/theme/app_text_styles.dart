import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography system for PhonicsFriends
/// PatrickHand  → big phoneme letters, display headings (fun, hand-written feel)
/// Nunito       → UI labels, body, buttons (clean, rounded, highly legible for kids)
abstract class AppTextStyles {
  // ── Display — PatrickHand ────────────────────────────────────
  /// Giant phoneme letter on lesson screen (e.g. "A")
  static const TextStyle phonemeDisplay = TextStyle(
    fontFamily: 'PatrickHand',
    fontSize: 120,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.0,
  );

  /// Section headers, screen titles
  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'PatrickHand',
    fontSize: 40,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: 'PatrickHand',
    fontSize: 32,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: 'PatrickHand',
    fontSize: 26,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // ── Headings — Nunito Bold ────────────────────────────────────
  static const TextStyle headingLarge = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle headingMedium = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle headingSmall = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // ── Body — Nunito Regular ─────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  // ── Labels & Buttons — Nunito Bold ───────────────────────────
  static const TextStyle buttonLarge = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: AppColors.textOnDark,
    letterSpacing: 0.5,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textOnDark,
    letterSpacing: 0.3,
  );

  static const TextStyle label = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    letterSpacing: 0.8,
  );

  // ── Special — Spelling Bee tiles ──────────────────────────────
  static const TextStyle spellingTile = TextStyle(
    fontFamily: 'PatrickHand',
    fontSize: 28,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // ── Score Display ─────────────────────────────────────────────
  static const TextStyle scoreDisplay = TextStyle(
    fontFamily: 'PatrickHand',
    fontSize: 72,
    fontWeight: FontWeight.w400,
    color: AppColors.coral,
    height: 1.0,
  );
}
