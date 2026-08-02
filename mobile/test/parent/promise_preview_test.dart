// Visual review of the screen where a parent answers their child's goal.
// Regenerate with:
//   flutter test --update-goldens test/parent/promise_preview_test.dart
//
// Almost all of the design here is wording, and wording is exactly what a
// unit test cannot judge. Three things have to be true when you look at
// it: the child's own goal is the first thing on the page and is plainly
// not editable, the prompt asks what the family will *do* rather than
// what the child will *get*, and the recording section says when the
// message will be heard before asking anyone to make one.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:phonics_app/core/theme/app_theme.dart';
import 'package:phonics_app/features/parent/presentation/screens/promise_screen.dart';

import '../support/preview_fonts.dart';

class _CannedAdapter implements HttpClientAdapter {
  Map<String, dynamic> promise;
  _CannedAdapter(this.promise);

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<List<int>>? _, Future<void>? __) async {
    return ResponseBody.fromString(
      jsonEncode(promise),
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
  late Map<String, dynamic> captured;
  late _CannedAdapter adapter;

  setUpAll(() async {
    await loadPreviewFonts();
    final payloads = jsonDecode(
      File('test/engagement/server_payloads.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    captured = payloads['parent_promise'] as Map<String, dynamic>;

    adapter = _CannedAdapter(captured);
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    GetIt.instance.registerSingleton<Dio>(dio);
  });

  tearDownAll(() => GetIt.instance.reset());

  Future<void> pump(WidgetTester tester, Map<String, dynamic> promise) async {
    adapter.promise = promise;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const PromiseScreen(childId: 1),
    ));
    await settleAnimations(tester, total: const Duration(seconds: 1));
  }

  testWidgets('the child\'s own goal comes first and is not the parent\'s to set',
      (tester) async {
    // Mid-week, which is when a parent actually writes this. The captured
    // payload is from a week already finished, so the counters are wound
    // back — everything else is exactly what the server sent.
    await pump(tester, {...captured, 'goal_done': 4, 'goal_is_complete': false});

    // Phrased so the parent cannot mistake this for a target they chose.
    expect(find.textContaining('They chose, themselves, to'), findsOneWidget);
    // Nothing on this screen offers to change it.
    expect(find.textContaining('Change goal'), findsNothing);
    expect(find.textContaining('Set a target'), findsNothing);

    // Asks for something done together, not something handed over.
    expect(find.text('What will you two do?'), findsOneWidget);
    expect(find.textContaining('a walk, a story'), findsOneWidget);
    expect(find.textContaining('buy'), findsNothing);
    expect(find.textContaining('reward'), findsNothing);

    // Says where the recording goes before asking for one.
    expect(find.textContaining('the moment they finish their week'),
        findsOneWidget);

    await expectLater(
      find.byType(PromiseScreen),
      matchesGoldenFile('parent_promise.png'),
    );
  });

  testWidgets('a week already kept says so, in the past tense', (tester) async {
    await pump(tester, captured);

    expect(find.text('They did it'), findsOneWidget);
    // Still offers the recording. A parent who hears about it late can
    // still leave something, and the child will find it waiting.
    expect(find.textContaining('Record again'), findsOneWidget);

    await expectLater(
      find.byType(PromiseScreen),
      matchesGoldenFile('parent_promise_kept.png'),
    );
  });

  testWidgets('a week with no goal chosen is not treated as a problem',
      (tester) async {
    await pump(tester, {
      ...captured,
      'goal_kind': null,
      'goal_target': 0,
      'goal_done': 0,
      'goal_is_complete': false,
    });

    expect(find.textContaining('have not chosen a goal yet'), findsOneWidget);
    // Not a warning, not a prompt to go and make them choose. Some weeks
    // a child does not, and the app has nothing to say about it.
    expect(find.textContaining('Remind'), findsNothing);
    expect(find.textContaining('should'), findsNothing);

    await expectLater(
      find.byType(PromiseScreen),
      matchesGoldenFile('parent_promise_no_goal.png'),
    );
  });
}
