// Design-system invariants.
//
// This replaces the `flutter create` scaffolding test, which pumped
// PhonicsApp directly. That has not been runnable since dependency
// injection was introduced: the app resolves TokenStorage from getIt in
// initState and the router then reads flutter_secure_storage, which needs
// platform channels a widget test does not have. Booting the whole app
// belongs in an integration test, not here.
//
// What follows guards the rules the visual language actually depends on —
// the ones easiest to undo by accident with a well-meaning edit.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/core/theme/app_colors.dart';
import 'package:phonics_app/core/theme/app_dimensions.dart';
import 'package:phonics_app/core/theme/app_text_styles.dart';

void main() {
  group('palette', () {
    test('red is never used to mean "wrong"', () {
      // The load-bearing rule of this app's colour system. A child marked
      // in red for mispronouncing a word learns that reading makes them
      // fail, and that is what stops children practising. "Not yet" is
      // amber; the red belongs to the mascot's crest and to celebration.
      expect(AppColors.retry, AppColors.honey);
      expect(AppColors.retry, isNot(AppColors.crest));
      expect(AppColors.correct, AppColors.leaf);
    });

    test('the ground is warm paper, not white', () {
      // Pure white glares on cheap screens and reads as clinical.
      expect(AppColors.parchment, isNot(const Color(0xFFFFFFFF)));
    });

    test('ink is warm, not neutral grey', () {
      // A neutral grey over a warm ground looks dirty; keeping the red
      // channel ahead of blue holds the ink in the warm family.
      const ink = AppColors.ink;
      expect(ink.r, greaterThan(ink.b));
    });
  });

  group('depth', () {
    test('shadows are hard offsets with no blur', () {
      // Two reasons, and they agree: a solid offset reads as cut paper
      // rather than the soft-blur look of generated UI, and blur is
      // expensive to rasterise on the low-end Android this app targets.
      for (final shadow in [
        ...AppShadows.card,
        ...AppShadows.raised,
        ...AppShadows.pressed,
        ...AppShadows.floating,
      ]) {
        expect(shadow.blurRadius, 0);
      }
    });

    test('depth is expressed by offset distance', () {
      expect(
        AppShadows.floating.first.offset.dy,
        greaterThan(AppShadows.raised.first.offset.dy),
      );
      expect(
        AppShadows.raised.first.offset.dy,
        greaterThan(AppShadows.pressed.first.offset.dy),
      );
    });

    test('a press closes exactly the gap it travels', () {
      // The translation and the shadow must stay in step, or the surface
      // stops reading as one object being pushed.
      final gap = AppShadows.raised.first.offset.dy -
          AppShadows.pressed.first.offset.dy;
      expect(AppShadows.pressTravel, gap);
    });
  });

  group('typography', () {
    test('taught letterforms are set in Nunito, not the handwriting face', () {
      // The giant phoneme and the words being decoded are the teaching
      // artifact, so they need canonical, consistent letterforms rather
      // than a handwriting face with uneven stroke weight.
      expect(AppTextStyles.phonemeDisplay.fontFamily, 'Nunito');
      expect(AppTextStyles.readingText.fontFamily, 'Nunito');
    });

    test('PatrickHand is reserved for the mascot voice', () {
      expect(AppTextStyles.mascotSpeech.fontFamily, 'PatrickHand');
    });

    test('touch targets clear the minimum for small fingers', () {
      expect(AppSizes.minTouchTarget, greaterThanOrEqualTo(48));
    });
  });
}
