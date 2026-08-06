// Visual preview of the sound screen. Regenerate with:
//   flutter test --update-goldens test/phonics/phoneme_card_preview_test.dart
//
// Three cases side by side, because they are the three shapes the card has
// to hold: one letter, one digraph, and a sound spelled two ways. They
// should read as the same lesson at three widths.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/core/theme/app_colors.dart';
import 'package:phonics_app/core/theme/app_theme.dart';
import 'package:phonics_app/features/phonics/domain/entities/lesson_entity.dart';
import 'package:phonics_app/features/phonics/presentation/widgets/phoneme_hero_card.dart';

import '../support/preview_fonts.dart';

PhonemeEntity phoneme(String symbol, String graphemes) => PhonemeEntity(
      id: 1,
      symbol: symbol,
      graphemes: graphemes,
      description: 'Voiceless labiodental fricative /f/ as in "fish".',
      type: 'ALPHABET',
      order: 1,
    );

void main() {
  setUpAll(loadPreviewFonts);

  testWidgets('the sound screen: one letter, a digraph, two spellings',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 460));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: Material(
          color: AppColors.background,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Row(
              children: [
                for (final p in [
                  phoneme('Aa', 'a'),
                  phoneme('ʃ (sh)', 'sh'),
                  phoneme('iː (ee/ea)', 'ee,ea'),
                ])
                  Expanded(
                    child: PhonemeHeroCard(
                      phoneme: p,
                      color: AppColors.leaf,
                      isPlayingAudio: false,
                      onPlayAudio: () {},
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await settleAnimations(tester, total: const Duration(milliseconds: 600));
    await expectLater(
      find.byType(Row).first,
      matchesGoldenFile('phoneme_card.png'),
    );
  });
}
