// The end of the day. Regenerate the picture with:
//   flutter test --update-goldens test/engagement/day_done_preview_test.dart
//
// This screen exists to stop, so what is worth checking is mostly what is
// absent from it. An app that plays the day for a child has to be able to
// say "that's everything" — and if this screen ever grows a "one more
// round", it has stopped being an ending and become a fourth activity.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/core/mascot/kiki.dart';
import 'package:phonics_app/core/theme/app_theme.dart';
import 'package:phonics_app/features/engagement/presentation/screens/day_done_screen.dart';

import '../support/preview_fonts.dart';

Future<void> pumpDone(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 780));
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    debugShowCheckedModeBanner: false,
    home: const DayDoneScreen(),
  ));
  await settleAnimations(tester, total: Kiki.settleDelay);
}

void main() {
  setUpAll(loadPreviewFonts);

  testWidgets('it tells the child they finished', (tester) async {
    await pumpDone(tester);

    // Past tense, and about them rather than about a score.
    expect(find.text('You did everything today!'), findsOneWidget);
    expect(find.text('A new sound is waiting tomorrow.'), findsOneWidget);
  });

  testWidgets('there is exactly one way on, and it is not more work',
      (tester) async {
    await pumpDone(tester);

    // One button. Two would be a choice, and the choice would be between
    // stopping and not stopping — which is not a choice to hand a
    // five-year-old at the end of their day.
    //
    // Matched by supertype rather than by TextButton, so swapping this for
    // an ElevatedButton does not quietly stop checking anything.
    expect(
      find.byWidgetPredicate((w) => w is ButtonStyleButton),
      findsOneWidget,
    );

    for (final pushy in ['again', 'more', 'next', 'keep going', 'Start']) {
      expect(find.textContaining(pushy), findsNothing,
          reason: 'the ending must not offer another activity');
    }
  });

  testWidgets('nothing counts what is left or what was missed',
      (tester) async {
    await pumpDone(tester);

    // No score, no tally, no target for tomorrow. The child is told they
    // finished; nothing here invites them to measure that.
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('/'), findsNothing);
    for (final counted in ['%', 'points', 'score', 'streak']) {
      expect(find.textContaining(counted), findsNothing);
    }
  });

  testWidgets('preview', (tester) async {
    await pumpDone(tester);
    await expectLater(
      find.byType(DayDoneScreen),
      matchesGoldenFile('day_done.png'),
    );
  });
}
