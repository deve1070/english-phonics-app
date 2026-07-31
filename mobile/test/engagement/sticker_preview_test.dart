// Visual review of the procedural collectibles. Regenerate with:
//   flutter test --update-goldens test/engagement/sticker_preview_test.dart
//
// The whole premise of SoundSticker is that ninety creatures can be
// derived from ninety ids without any artwork. That claim is only
// checkable by looking, so this renders a strip of them — unlocked and
// locked — for eyeballing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/core/theme/app_colors.dart';
import 'package:phonics_app/core/theme/app_theme.dart';
import 'package:phonics_app/features/engagement/presentation/widgets/sound_sticker.dart';

import '../support/preview_fonts.dart';

const _symbols = ['Aa', 'Bb', 'Cc', 'Dd', 'Ee', 'Ff', 'Gg', 'sh'];

void main() {
  setUpAll(loadPreviewFonts);

  testWidgets('collectibles are distinct, awake and asleep', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Material(
        color: AppColors.parchment,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final unlocked in [true, false])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (var i = 0; i < _symbols.length; i++)
                        SoundSticker(
                          phonemeId: i + 1,
                          symbol: _symbols[i],
                          isUnlocked: unlocked,
                          size: 76,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ));
    await settleAnimations(tester, total: const Duration(milliseconds: 400));

    await expectLater(
      find.byType(Column).first,
      matchesGoldenFile('stickers.png'),
    );
  });
}
