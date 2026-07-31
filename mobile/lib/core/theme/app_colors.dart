import 'package:flutter/material.dart';

/// Palette derived from the Abyssinian lovebird (Agapornis taranta), the
/// highland parrot this app's mascot is based on, and from the warm earth
/// tones of the Ethiopian highlands.
///
/// Deliberately NOT the coral/teal/pastel-yellow set this replaced — that
/// combination is the default "friendly kids app" palette and reads as
/// stock. These colours are saturated and warm rather than washed out, and
/// every surface is a flat fill: there are no gradients anywhere in the
/// system.
///
/// One rule matters more than the rest: **red never means "wrong."** In an
/// app where a child reads aloud and is scored, red marking failure teaches
/// shame, and shame is what stops children practising. [honey] carries
/// "try again". [crest] is reserved for the bird and for celebration.
abstract class AppColors {
  // ── Core palette ──────────────────────────────────────────────
  /// Her plumage. Primary actions, progress, success. Deep and saturated —
  /// not mint, not teal.
  static const Color leaf = Color(0xFF2E7D4F);
  static const Color leafDark = Color(0xFF1F5C39);
  static const Color leafLight = Color(0xFFDCEBE0);

  /// The red forehead patch. Accent and celebration only — never failure.
  static const Color crest = Color(0xFFC8102E);
  static const Color crestLight = Color(0xFFF7DDE1);

  /// Ochre. Replaces the neon yellow: warmer, and readable as a "keep
  /// going" signal rather than an alarm.
  static const Color honey = Color(0xFFE0A33E);
  static const Color honeyLight = Color(0xFFFBEEDA);

  /// Muted highland blue. Secondary and informational.
  static const Color sky = Color(0xFF4A7FA5);
  static const Color skyLight = Color(0xFFDDE8F0);

  // ── Ground & surface ──────────────────────────────────────────
  /// Warm paper, not white. White backgrounds glare on cheap screens and
  /// read as clinical.
  static const Color parchment = Color(0xFFF5EFE3);
  static const Color surface = Color(0xFFFFFDF8);
  static const Color surfaceSunken = Color(0xFFEBE3D4);

  // ── Ink ───────────────────────────────────────────────────────
  /// Warm brown-black. A neutral grey against warm paper looks dirty.
  static const Color ink = Color(0xFF2B241E);
  static const Color inkSoft = Color(0xFF6B5F52);
  static const Color inkFaint = Color(0xFFA79683);
  static const Color onInk = Color(0xFFFFFDF8);

  // ── Semantic ──────────────────────────────────────────────────
  /// Got it. The same green as the brand — success is the state we want
  /// children to associate with the app by default.
  static const Color correct = leaf;

  /// Not yet. Deliberately amber rather than red: this is an invitation to
  /// retry, and retries are free (the server always keeps the best score).
  static const Color retry = honey;

  /// Not attempted / locked.
  static const Color dormant = Color(0xFFC9BCA9);

  // ── Structure ─────────────────────────────────────────────────
  static const Color border = Color(0xFF2B241E);
  static const Color borderSoft = Color(0xFFD9CDB9);

  /// Hard offset shadow, no blur. See [AppShadows] for why.
  static const Color shadow = Color(0xFF2B241E);

  // ── Lesson levels ─────────────────────────────────────────────
  // Ordered as a journey that gets richer, not five unrelated hues.
  static const Color level1 = leaf;
  static const Color level2 = sky;
  static const Color level3 = honey;
  static const Color level4 = Color(0xFF8C5AA8); // highland iris
  static const Color level5 = crest;

  // ── Backwards-compatible aliases ──────────────────────────────
  // The old names are still referenced by screens not yet restyled. They
  // resolve into the new palette so nothing renders in the old stock
  // colours during the migration. Prefer the names above in new code.
  static const Color coral = crest;
  static const Color teal = leaf;
  static const Color yellow = honey;
  static const Color purple = level4;
  static const Color green = leaf;
  static const Color red = crest;
  static const Color orange = honey;
  static const Color background = parchment;
  static const Color surfaceVariant = surfaceSunken;
  static const Color textPrimary = ink;
  static const Color textSecondary = inkSoft;
  static const Color textOnDark = onInk;
  static const Color divider = borderSoft;
  static const Color shadowLight = Color(0x142B241E);
  static const Color shadowMedium = Color(0x1F2B241E);
}
