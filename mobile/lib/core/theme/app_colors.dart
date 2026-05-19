import 'package:flutter/material.dart';

/// PhonicsFriends color palette — derived from the web app (phoneticsap.vercel.app)
abstract class AppColors {
  // ── Brand Primaries ──────────────────────────────────────────
  static const Color coral = Color(0xFFFF6B6B);        // primary CTAs, headers
  static const Color teal = Color(0xFF4ECDC4);          // secondary, success states
  static const Color yellow = Color(0xFFFFE66D);        // accents, highlights
  static const Color purple = Color(0xFFA855F7);        // Spelling Bee feature

  // ── Semantic ──────────────────────────────────────────────────
  static const Color green = Color(0xFF6BCB77);         // correct answer
  static const Color red = Color(0xFFFF6B6B);           // wrong answer (same coral)
  static const Color orange = Color(0xFFFF9F43);        // warning / in-progress

  // ── Background & Surface ─────────────────────────────────────
  static const Color background = Color(0xFFFFF9F0);   // warm white — main bg
  static const Color surface = Color(0xFFFFFFFF);      // cards, modals
  static const Color surfaceVariant = Color(0xFFF5EFE6); // subtle card bg

  // ── Text ──────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF2D2D2D);  // headings, labels
  static const Color textSecondary = Color(0xFF7A7A8A); // subtitles, hints
  static const Color textOnDark = Color(0xFFFFFFFF);   // text on coral/teal bg

  // ── Borders & Dividers ────────────────────────────────────────
  static const Color border = Color(0xFFE8DFD0);
  static const Color divider = Color(0xFFF0E8DC);

  // ── Shadows ───────────────────────────────────────────────────
  static const Color shadowLight = Color(0x1A2D2D2D);
  static const Color shadowMedium = Color(0x262D2D2D);

  // ── Lesson Level Colors ───────────────────────────────────────
  static const Color level1 = Color(0xFF4ECDC4); // teal
  static const Color level2 = Color(0xFFFFE66D); // yellow
  static const Color level3 = Color(0xFFFF6B6B); // coral
  static const Color level4 = Color(0xFFA855F7); // purple
  static const Color level5 = Color(0xFFFF9F43); // orange

  // ── Gradients ─────────────────────────────────────────────────
  static const LinearGradient coralGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient tealGradient = LinearGradient(
    colors: [Color(0xFF4ECDC4), Color(0xFF38B2A9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient yellowGradient = LinearGradient(
    colors: [Color(0xFFFFE66D), Color(0xFFFFD93D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFFA855F7), Color(0xFF9333EA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFFFF9F0), Color(0xFFFFF3E0)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}