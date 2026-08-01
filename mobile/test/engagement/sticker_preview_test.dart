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
    // Three rows, because there are three states and the middle one is
    // the whole point of the recognition track: a creature that has
    // opened its eyes but is still grey has to read as further along than
    // a sleeping one and not as far as a mastered one. If the middle row
    // is indistinguishable from either neighbour, that reward is invisible
    // and the child gets nothing for the work.
    const states = [
      (unlocked: true, recognised: true),
      (unlocked: false, recognised: true),
      (unlocked: false, recognised: false),
    ];

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Material(
        color: AppColors.parchment,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final state in states)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (var i = 0; i < _symbols.length; i++)
                        SoundSticker(
                          phonemeId: i + 1,
                          symbol: _symbols[i],
                          isUnlocked: state.unlocked,
                          isRecognised: state.recognised,
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
