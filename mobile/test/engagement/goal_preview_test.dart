// Visual review of the week's promise and its prize. Regenerate with:
//   flutter test --update-goldens test/engagement/goal_preview_test.dart
//
// Everything load-bearing here is a picture. Whether three options read as
// three genuine choices rather than three sizes of the same chore, whether
// a half-filled medal reads as "part-way" rather than "broken", and whether
// last week's prize is distinguishable from this week's on the shelf — none
// of that can be asserted, only looked at.
//
// The screen is driven against the captured server payloads, so what is
// rendered is what a real child's device would render.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:phonics_app/core/theme/app_theme.dart';
import 'package:phonics_app/features/engagement/data/engagement_models.dart';
import 'package:phonics_app/features/engagement/presentation/widgets/week_medal.dart';
import 'package:phonics_app/features/engagement/presentation/screens/goal_screen.dart';

import '../support/preview_fonts.dart';

/// Answers /me/goal with whichever captured state the test is showing.
class _CannedAdapter implements HttpClientAdapter {
  Map<String, dynamic> goal;
  _CannedAdapter(this.goal);

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<List<int>>? _, Future<void>? __) async {
    return ResponseBody.fromString(
      jsonEncode(goal),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Map<String, dynamic> payloads;
  late _CannedAdapter adapter;

  setUpAll(() async {
    await loadPreviewFonts();
    payloads = jsonDecode(
      File('test/engagement/server_payloads.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    adapter = _CannedAdapter(payloads['goal_offer'] as Map<String, dynamic>);
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    GetIt.instance.registerSingleton<Dio>(dio);
  });

  tearDownAll(() => GetIt.instance.reset());

  Future<void> pumpWith(WidgetTester tester, String state) async {
    adapter.goal = payloads[state] as Map<String, dynamic>;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const GoalScreen(),
    ));
    await settleAnimations(tester, total: const Duration(seconds: 2));
  }

  testWidgets('Monday offers three things and shows what each leaves behind',
      (tester) async {
    await pumpWith(tester, 'goal_offer');

    expect(find.text('What will you do this week?'), findsOneWidget);
    // Said out loud, because a child weighing three options needs to know
    // that none of them is the trap.
    expect(find.text('Pick one. You can do any of them.'), findsOneWidget);

    final choices = (payloads['goal_offer']['choices'] as List);
    expect(choices, hasLength(3));

    await expectLater(
      find.byType(GoalScreen),
      matchesGoldenFile('goal_offer.png'),
    );
  });

  testWidgets('part-way through, the prize is part-filled and nothing scolds',
      (tester) async {
    await pumpWith(tester, 'goal_partway');

    final goal = payloads['goal_partway'] as Map<String, dynamic>;
    expect(find.text('${goal['done']} of ${goal['target']} sounds'),
        findsOneWidget);

    // A week going slowly is drawn as a medal that has not filled up much.
    // If any of these ever appear, the feature has started keeping a
    // record of failure — which is the one thing it must not do.
    expect(find.textContaining('behind'), findsNothing);
    expect(find.textContaining('left'), findsNothing);
    expect(find.textContaining('missed'), findsNothing);
    expect(find.text('You did it!'), findsNothing);

    await expectLater(
      find.byType(GoalScreen),
      matchesGoldenFile('goal_partway.png'),
    );
  });

  testWidgets('a message from home is announced without being dangled',
      (tester) async {
    await pumpWith(tester, 'goal_promise_sealed');

    final promise = (payloads['goal_promise_sealed']
        as Map<String, dynamic>)['promise'] as Map<String, dynamic>;
    final name = promise['parent_name'] as String;

    expect(find.text('$name said:'), findsOneWidget);
    expect(find.text(promise['text'] as String), findsOneWidget);
    expect(find.text('$name left you a message for when you finish.'),
        findsOneWidget);

    // Nothing that turns the promise into leverage. "If you don't" and
    // any countdown make a threat out of a gift, and a child who reads it
    // that way has been given a reason to dread the week rather than
    // want it.
    expect(find.textContaining('If you'), findsNothing);
    expect(find.textContaining('only'), findsNothing);
    expect(find.textContaining('left to go'), findsNothing);

    await expectLater(
      find.byType(GoalScreen),
      matchesGoldenFile('goal_promise_sealed.png'),
    );
  });

  testWidgets('finishing turns the message into a button', (tester) async {
    await pumpWith(tester, 'goal_promise_open');

    final promise = (payloads['goal_promise_open']
        as Map<String, dynamic>)['promise'] as Map<String, dynamic>;
    final name = promise['parent_name'] as String;

    expect(find.text('Listen to $name'), findsOneWidget);
    expect(find.text('You did it!'), findsOneWidget);

    await expectLater(
      find.byType(GoalScreen),
      matchesGoldenFile('goal_promise_open.png'),
    );
  });

  testWidgets('the prize fills evenly from empty to whole', (tester) async {
    // The same widget the home card uses, at the size it uses. A medal
    // whose coloured half sits out of register with its grey half reads as
    // a broken picture, and this is a small enough strip to see it in.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in [0.0, 0.25, 0.5, 0.75, 1.0])
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: FillingMedal(
                    weekStart: DateTime.utc(2026, 7, 27),
                    kind: GoalKind.soundsFound,
                    fraction: f,
                    size: 56,
                  ),
                ),
            ],
          ),
        ),
      ),
    ));
    await settleAnimations(tester, total: const Duration(milliseconds: 300));

    await expectLater(
      find.byType(Row).first,
      matchesGoldenFile('goal_medal_filling.png'),
    );
  });

  testWidgets('a week kept is said in the past tense, and joins the shelf',
      (tester) async {
    await pumpWith(tester, 'goal_kept');

    expect(find.text('You did it!'), findsOneWidget);
    // About them and about what they decided, not about the app being
    // pleased with them.
    expect(find.text('You said you would, and you did.'), findsOneWidget);
    expect(find.text('Weeks you kept'), findsOneWidget);

    await expectLater(
      find.byType(GoalScreen),
      matchesGoldenFile('goal_kept.png'),
    );
  });
}
