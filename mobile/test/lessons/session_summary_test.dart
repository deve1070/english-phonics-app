import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/core/theme/app_colors.dart';
import 'package:phonics_app/core/theme/app_theme.dart';
import 'package:phonics_app/features/lessons/presentation/widgets/session_summary_sheet.dart';

import '../support/preview_fonts.dart';

void main() {
  setUpAll(loadPreviewFonts);

  group('SessionTracker', () {
    test('starts empty so a summary is skipped when nothing was attempted',
        () {
      expect(SessionTracker().build().isEmpty, isTrue);
    });

    test('accumulates stars using the shared thresholds', () {
      final t = SessionTracker()
        ..recordAttempt(score: 99, sound: 'cat') // 3
        ..recordAttempt(score: 91, sound: 'dog') // 2
        ..recordAttempt(score: 82, sound: 'sun') // 1
        ..recordAttempt(score: 40, sound: 'fig'); // 0

      final tally = t.build();
      expect(tally.exercisesAttempted, 4);
      expect(tally.starsEarned, 6);
      expect(tally.isEmpty, isFalse);
    });

    test('lists each sound once, in the order met', () {
      final t = SessionTracker()
        ..recordAttempt(score: 90, sound: 'cat')
        ..recordAttempt(score: 50, sound: 'cat')
        ..recordAttempt(score: 90, sound: 'dog');

      expect(t.build().soundsPractised, ['cat', 'dog']);
    });

    test('ignores blank sounds but still counts the attempt', () {
      final t = SessionTracker()..recordAttempt(score: 90, sound: '  ');
      expect(t.build().soundsPractised, isEmpty);
      expect(t.build().exercisesAttempted, 1);
    });

    test('reset clears the sitting', () {
      final t = SessionTracker()..recordAttempt(score: 90, sound: 'cat');
      t.reset();
      expect(t.build().isEmpty, isTrue);
    });
  });

  group('SessionSummarySheet', () {
    testWidgets('shows the tally and dismisses on Done', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => SessionSummarySheet.show(
                  context,
                  tally: const SessionTally(
                    exercisesAttempted: 5,
                    starsEarned: 9,
                    soundsPractised: ['Aa', 'Bb'],
                    streakDays: 3,
                    streakAdvanced: true,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pump();
      await settleAnimations(tester, total: const Duration(seconds: 2));

      expect(find.text('Great practice!'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('Aa'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await settleAnimations(tester, total: const Duration(seconds: 1));
      expect(find.text('Great practice!'), findsNothing);
    });

    testWidgets('frames the daily cap as finishing, not being cut off',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Material(
          color: AppColors.parchment,
          child: SessionSummarySheet(
            tally: const SessionTally(exercisesAttempted: 3, starsEarned: 4),
            reachedDailyLimit: true,
            onDone: () {},
          ),
        ),
      ));
      await settleAnimations(tester, total: const Duration(seconds: 1));

      expect(find.text("That's today's reading done!"), findsOneWidget);
      // Nothing that reads as a punishment or a door closing.
      expect(find.textContaining("Time's up"), findsNothing);
    });
  });
}
