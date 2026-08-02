// Visual review of the listening game. Regenerate with:
//   flutter test --update-goldens test/engagement/recognition_preview_test.dart
//
// The game is almost entirely wordless — a bird, a speaker, and some
// letters on cards — so the only way to know whether a six-year-old can
// tell what to do is to look at it. This drives the real screen against a
// canned round rather than rebuilding its pieces, so what is rendered is
// what ships: the question as it is asked, the moment after a right
// answer, and the moment after a wrong one.
//
// The taps are also the test. "Tap to listen, tap again to pick" is a
// gesture nobody can see, and if the first tap ever starts answering
// instead of playing, a child will be marked wrong for listening.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:phonics_app/core/theme/app_theme.dart';
import 'package:phonics_app/features/engagement/presentation/screens/recognition_screen.dart';

import '../support/preview_fonts.dart';

/// Answers /me/recognition/round from the captured fixture and everything
/// else (audio fetches) with empty bytes.
class _CannedAdapter implements HttpClientAdapter {
  final Map<String, dynamic> round;

  /// What /me/goal answers with. Null means "no goal", which is what the
  /// ordinary tests want; a completed one is how the round that finishes
  /// a child's week is staged.
  Map<String, dynamic>? goal;

  _CannedAdapter(this.round);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? _,
      Future<void>? __) async {
    if (options.path.contains('goal')) {
      final body = goal;
      if (body == null) return ResponseBody.fromBytes(const [], 404);
      return ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.path.contains('recognition')) {
      return ResponseBody.fromString(
        jsonEncode(options.method == 'GET'
            ? round
            : {'recorded': 5, 'newly_recognised': [], 'total_recognised': 0}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromBytes(const [], 200);
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _pumpGame(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: const RecognitionScreen(),
  ));
  // Long enough for the round to arrive and the first question to settle.
  await settleAnimations(tester, total: const Duration(milliseconds: 800));
}

/// Close the screen the way a child walking away would, and let what that
/// sets off finish.
///
/// Two things are still in flight at the end of an answered question: the
/// pause before the next one, and — once the tree comes down — the post of
/// the part-finished round, which is the behaviour that stops a child
/// losing what they did. Both have to be let run or the test binding
/// reports them as leaked timers.
Future<void> _closeAndSettle(WidgetTester tester) async {
  await settleAnimations(tester, total: const Duration(seconds: 3));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
}

Finder _card(String grapheme) => find.ancestor(
      of: find.text(grapheme),
      matching: find.byType(SizedBox),
    ).first;

void main() {
  late Map<String, dynamic> round;
  late Map<String, dynamic> payloads;
  late _CannedAdapter adapter;

  setUpAll(() async {
    await loadPreviewFonts();
    payloads = jsonDecode(
      File('test/engagement/server_payloads.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    round = payloads['recognition_explore'] as Map<String, dynamic>;

    adapter = _CannedAdapter(round);
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    GetIt.instance.registerSingleton<Dio>(dio);
  });

  tearDown(() => adapter.goal = null);

  tearDownAll(() => GetIt.instance.reset());

  testWidgets('a question is legible before anything is chosen',
      (tester) async {
    await _pumpGame(tester);

    // Every option's spelling is on screen, which is the only thing the
    // child has to go on.
    final options = (round['questions'] as List).first['options'] as List;
    for (final option in options) {
      expect(find.text(option['grapheme'] as String), findsWidgets);
    }

    await expectLater(
      find.byType(RecognitionScreen),
      matchesGoldenFile('recognition_question.png'),
    );
  });

  testWidgets('in explore, the first tap listens and does not answer',
      (tester) async {
    await _pumpGame(tester);

    final question = (round['questions'] as List).first as Map<String, dynamic>;
    final wrong = (question['options'] as List).firstWhere(
      (o) => o['phoneme_id'] != question['target_phoneme_id'],
    ) as Map<String, dynamic>;

    await tester.tap(_card(wrong['grapheme'] as String));
    await settleAnimations(tester, total: const Duration(milliseconds: 400));

    // Still asking. If this ever fails, a child who tapped a card to hear
    // it has just been marked wrong for listening — which is the exact
    // thing the two-tap gesture exists to prevent.
    expect(find.text('Tap to listen. Tap again to pick.'), findsOneWidget);
    expect(find.text('Yes!'), findsNothing);

    await expectLater(
      find.byType(RecognitionScreen),
      matchesGoldenFile('recognition_listening.png'),
    );
  });

  testWidgets('the second tap on the same card answers', (tester) async {
    await _pumpGame(tester);

    final question = (round['questions'] as List).first as Map<String, dynamic>;
    final right = (question['options'] as List).firstWhere(
      (o) => o['phoneme_id'] == question['target_phoneme_id'],
    ) as Map<String, dynamic>;
    final grapheme = right['grapheme'] as String;

    await tester.tap(_card(grapheme));
    await settleAnimations(tester, total: const Duration(milliseconds: 200));
    await tester.tap(_card(grapheme));
    await settleAnimations(tester, total: const Duration(milliseconds: 400));

    expect(find.text('Yes!'), findsOneWidget);

    await expectLater(
      find.byType(RecognitionScreen),
      matchesGoldenFile('recognition_right.png'),
    );
    await _closeAndSettle(tester);
  });

  testWidgets('the round that finishes the week says so, and who is waiting',
      (tester) async {
    // Where a week is nearly always kept: mid-round, on the answer that
    // crosses the target. A child who finishes here and is told nothing
    // would have to go looking for the message their parent left them.
    adapter.goal = payloads['goal_promise_open'] as Map<String, dynamic>;
    await _pumpGame(tester);
    await _playThrough(tester, round);

    expect(find.text('You finished your week!'), findsOneWidget);
    expect(find.text('Almaz left you a message. Tap to hear it.'),
        findsOneWidget);

    await expectLater(
      find.byType(RecognitionScreen),
      matchesGoldenFile('recognition_week_kept.png'),
    );
    await _closeAndSettle(tester);
  });

  testWidgets('an ordinary round says nothing about a week', (tester) async {
    // The common case, and it must stay quiet. A summary that mentioned
    // the goal every time would turn every round into a progress report.
    await _pumpGame(tester);
    await _playThrough(tester, round);

    expect(find.text('You finished your week!'), findsNothing);
    await _closeAndSettle(tester);
  });

  testWidgets('a wrong answer shows the right one saying itself',
      (tester) async {
    await _pumpGame(tester);

    final question = (round['questions'] as List).first as Map<String, dynamic>;
    final wrong = (question['options'] as List).firstWhere(
      (o) => o['phoneme_id'] != question['target_phoneme_id'],
    ) as Map<String, dynamic>;
    final grapheme = wrong['grapheme'] as String;

    await tester.tap(_card(grapheme));
    await settleAnimations(tester, total: const Duration(milliseconds: 200));
    await tester.tap(_card(grapheme));
    await settleAnimations(tester, total: const Duration(milliseconds: 500));

    // Not "wrong", not a cross. The correct card lights up and plays, so
    // the last thing the child experiences is the true pairing.
    expect(find.text('This one says it.'), findsOneWidget);

    await expectLater(
      find.byType(RecognitionScreen),
      matchesGoldenFile('recognition_wrong.png'),
    );
    await _closeAndSettle(tester);
  });
}

/// Play a whole round correctly, which is what it takes to reach the
/// summary — there is no shortcut to it, and the round that finishes a
/// child's week is the one worth looking at.
Future<void> _playThrough(WidgetTester tester, Map<String, dynamic> round) async {
  for (final q in (round['questions'] as List).cast<Map<String, dynamic>>()) {
    final right = (q['options'] as List).firstWhere(
      (o) => o['phoneme_id'] == q['target_phoneme_id'],
    ) as Map<String, dynamic>;
    final grapheme = right['grapheme'] as String;

    await tester.tap(_card(grapheme));
    await settleAnimations(tester, total: const Duration(milliseconds: 200));
    await tester.tap(_card(grapheme));
    // Long enough for the pause between questions to run out.
    await settleAnimations(tester, total: const Duration(seconds: 3));
  }
}
