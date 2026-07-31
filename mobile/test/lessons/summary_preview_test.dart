// Visual preview. Regenerate:
//   flutter test --update-goldens test/lessons/summary_preview_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/core/theme/app_colors.dart';
import 'package:phonics_app/core/theme/app_theme.dart';
import 'package:phonics_app/features/lessons/presentation/widgets/session_summary_sheet.dart';

import '../support/preview_fonts.dart';

void main() {
  setUpAll(loadPreviewFonts);

  testWidgets('session summary sheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 640));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: Material(
        color: AppColors.parchment,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SessionSummarySheet(
            tally: const SessionTally(
              exercisesAttempted: 6,
              starsEarned: 11,
              soundsPractised: ['Aa', 'Bb', 'Cc'],
              streakDays: 4,
              streakAdvanced: true,
            ),
            onDone: () {},
          ),
        ),
      ),
    ));
    await settleAnimations(tester, total: const Duration(milliseconds: 1600));
    await expectLater(find.byType(SessionSummarySheet),
        matchesGoldenFile('session_summary.png'));
  });
}
