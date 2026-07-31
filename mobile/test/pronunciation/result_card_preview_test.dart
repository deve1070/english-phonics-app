// Visual preview of the post-attempt card. Regenerate with:
//   flutter test --update-goldens test/pronunciation/result_card_preview_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/core/mascot/kiki.dart';
import 'package:phonics_app/core/theme/app_colors.dart';
import 'package:phonics_app/core/theme/app_theme.dart';
import 'package:phonics_app/features/pronunciation/presentation/cubit/pronunciation_state.dart';
import 'package:phonics_app/features/pronunciation/presentation/widgets/score_result_card.dart';

import '../support/preview_fonts.dart';

void main() {
  setUpAll(loadPreviewFonts);

  testWidgets('result card: strong and weak attempt', (tester) async {
    await tester.binding.setSurfaceSize(const Size(820, 700));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      // Material ancestor required: without one Flutter paints the
      // yellow "missing Material" underline under every Text.
      home: Material(
        color: AppColors.parchment,
        child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(children: [
          Expanded(child: SingleChildScrollView(child: ScoreResultCard(
            state: const PronunciationScored(
              score: 92, exerciseId: 1, isCompleted: true,
              heardText: 'The cat sat on a mat', isPersonalBest: true),
            expectedText: 'The cat sat on a mat.',
            onTryAgain: () {}, onNext: () {}))),
          Expanded(child: SingleChildScrollView(child: ScoreResultCard(
            state: const PronunciationScored(
              score: 58, exerciseId: 1, isCompleted: false,
              heardText: 'The cat on mat'),
            expectedText: 'The cat sat on a mat.',
            onTryAgain: () {}, onNext: () {}))),
        ]),
      )),
    ));
    // The card contains Kiki, whose blink interval is random. Settle
    // everything the card animates but stop short of her first possible
    // blink, or this golden drifts by a few hundred pixels at random.
    await settleAnimations(
      tester,
      total: Kiki.minBlinkDelay - const Duration(milliseconds: 300),
    );
    await expectLater(find.byType(Row).first,
        matchesGoldenFile('result_card.png'));
  });
}
