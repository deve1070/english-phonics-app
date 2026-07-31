import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography system.
///
/// Nunito       → everything a child has to *read as language*, including
///                the letterforms being taught.
/// PatrickHand  → decorative headings only, for warmth.
///
/// The split matters pedagogically. Both faces happen to have the correct
/// single-storey `a` and `g` — the shapes children are actually taught to
/// write, rather than the double-storey `ɑ` most text faces use — so either
/// is defensible for body text. But PatrickHand is a handwriting face with
/// uneven stroke weight, and the giant phoneme letter is not decoration:
/// it is the artifact being taught. That one needs to be canonical and
/// perfectly consistent every time it appears, so it is set in Nunito
/// Black.
///
/// Known caveat: Nunito draws capital `I` and lowercase `l` as the same
/// bare stem. Phonics work here is overwhelmingly lowercase and the display
/// pairs letters as "Aa", so this rarely bites — but avoid Nunito for any
/// screen where a child must tell those two apart in isolation.
abstract class AppTextStyles {
  // ── The letterforms being taught — Nunito Black ──────────────
  /// Giant phoneme letter on the lesson screen (e.g. "Aa").
  static const TextStyle phonemeDisplay = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 120,
    fontWeight: FontWeight.w900,
    color: AppColors.ink,
    height: 1.0,
    letterSpacing: -1,
  );

  /// A word or sentence the child is being asked to read aloud. Same
  /// reasoning as [phonemeDisplay]: this is the thing being decoded, so it
  /// must be set in canonical letterforms, generously tracked.
  static const TextStyle readingText = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
    height: 1.45,
    letterSpacing: 0.5,
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
  /// Numeric score. Parent-facing surfaces only — children see stars.
  static const TextStyle scoreDisplay = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 56,
    fontWeight: FontWeight.w900,
    color: AppColors.leaf,
    height: 1.0,
  );

  /// Short celebratory lines from the mascot. PatrickHand earns its place
  /// here: it is voice, not instruction.
  static const TextStyle mascotSpeech = TextStyle(
    fontFamily: 'PatrickHand',
    fontSize: 26,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
    height: 1.3,
  );
}
