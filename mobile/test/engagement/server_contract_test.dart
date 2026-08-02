// The client's half of the contract, checked against what the server
// actually sends rather than against what the client assumes.
//
// server_payloads.json was captured from a live backend
// (backend/scripts/verify_basic_functions.py sets up the same accounts).
// Every other test in this directory feeds the models JSON I wrote by
// hand, which proves only that the parser agrees with me. This one fails
// if the API changes shape underneath the app — regenerate the fixture
// from a running server when it does, and the diff is the breakage.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/features/engagement/data/engagement_models.dart';

void main() {
  late Map<String, dynamic> payloads;

  setUpAll(() {
    payloads = jsonDecode(
      File('test/engagement/server_payloads.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  test('the quest payload parses', () {
    final quest =
        DailyQuest.fromJson(payloads['quest'] as Map<String, dynamic>);

    expect(quest.items, isNotEmpty);
    expect(quest.items.length, quest.items.map((i) => i.slot).toSet().length,
        reason: 'the server sent two items in the same slot');
    for (final item in quest.items) {
      expect(item.content, isNotEmpty);
      expect(item.exerciseId, greaterThan(0));
    }
    expect(quest.completedCount, lessThanOrEqualTo(quest.items.length));
  });

  test('the streak payload parses', () {
    final streak =
        StreakInfo.fromJson(payloads['streak'] as Map<String, dynamic>);
    expect(streak.days, greaterThanOrEqualTo(0));
    expect(streak.freezesAvailable, greaterThanOrEqualTo(0));
  });

  test('the collection payload parses, gaps included', () {
    final collection =
        Collection.fromJson(payloads['collection'] as Map<String, dynamic>);

    expect(collection.total, greaterThan(0));
    expect(collection.items, isNotEmpty);
    for (final item in collection.items) {
      expect(item.symbol, isNotEmpty);
      // Drives the procedural sticker; a zero here would give every
      // creature the same appearance.
      expect(item.phonemeId, greaterThan(0));
    }
  });

  test('a recognition round parses and every question is answerable', () {
    for (final key in ['recognition_explore', 'recognition_choose']) {
      final round =
          RecognitionRound.fromJson(payloads[key] as Map<String, dynamic>);

      expect(round.questions, isNotEmpty, reason: '$key came back empty');
      for (final question in round.questions) {
        // The answer travels with the question so the app can mark it on
        // the device. Without it there is nothing to mark against and the
        // game cannot run at all.
        expect(
          question.options.map((o) => o.phonemeId),
          contains(question.targetPhonemeId),
          reason: 'a question arrived with no correct option on screen',
        );
        expect(question.options.length, greaterThanOrEqualTo(2));
        expect(question.options.length, lessThanOrEqualTo(4));
        expect(
          question.options.map((o) => o.phonemeId).toSet().length,
          question.options.length,
          reason: 'the same sound was offered twice in one question',
        );
        for (final option in question.options) {
          // The card shows the spelling. An empty one would render a
          // blank tile with nothing to choose between.
          expect(option.grapheme.isNotEmpty || option.symbol.isNotEmpty, isTrue);
          expect(option.audioUrl, isNotEmpty);
        }
      }
    }
  });

  test('a brand-new child gets a real round, not the same pair repeatedly', () {
    final round = RecognitionRound.fromJson(
        payloads['recognition_explore'] as Map<String, dynamic>);

    // Captured from a child who had done nothing at all. Two sounds
    // rotating for five questions is what this used to be, and it is not
    // a game — the frontier has to open wide enough on day one.
    final targets = round.questions.map((q) => q.targetPhonemeId).toSet();
    expect(targets.length, greaterThanOrEqualTo(3),
        reason: 'a first round asked about almost nothing');
  });

  test('the round summary parses', () {
    final summary = RecognitionSummary.fromJson(
        payloads['recognition_summary'] as Map<String, dynamic>);
    expect(summary.recorded, greaterThan(0));
    expect(summary.totalRecognised, greaterThanOrEqualTo(0));
  });

  test('the collection carries the recognised flag', () {
    final collection = Collection.fromJson(
        payloads['collection_fresh'] as Map<String, dynamic>);

    expect(collection.items, isNotEmpty);
    for (final item in collection.items) {
      // A sound cannot be recognised without being asked about, and this
      // child was captured before answering anything. The flag existing
      // at all is what the sticker's third state depends on.
      expect(item.isRecognised, isFalse);
    }
  });

  test('a week with nothing chosen offers three reachable things', () {
    final goal =
        WeeklyGoal.fromJson(payloads['goal_offer'] as Map<String, dynamic>);

    expect(goal.isChosen, isFalse);
    expect(goal.choices.length, 3,
        reason: 'a child was given fewer than three ways to spend the week');
    expect(goal.choices.map((c) => c.kind).toSet().length, 3,
        reason: 'the same kind was offered twice');
    for (final choice in goal.choices) {
      expect(choice.target, greaterThan(0),
          reason: 'a goal of zero is not a goal');
    }

    // Captured from a child who had done nothing at all — the first week
    // is the one most likely to be sized wrong, and getting it wrong here
    // is how a child learns that goals are for other people.
    final days = goal.choices.firstWhere((c) => c.kind == GoalKind.days);
    expect(days.target, lessThan(7),
        reason: 'a first week that needs every day is a week with no slack');
  });

  test('a promise part-way through draws a part-filled prize', () {
    final goal =
        WeeklyGoal.fromJson(payloads['goal_partway'] as Map<String, dynamic>);

    expect(goal.isChosen, isTrue);
    expect(goal.isComplete, isFalse);
    expect(goal.done, greaterThan(0));
    expect(goal.done, lessThan(goal.target));
    expect(goal.fraction, greaterThan(0));
    expect(goal.fraction, lessThan(1));
    // Nothing to choose from while a promise stands: a client that could
    // show three alternatives could let a child swap on Saturday for
    // whichever one is nearly done.
    expect(goal.choices, isEmpty);
  });

  test('a week kept fills the prize and puts it on the shelf', () {
    final goal =
        WeeklyGoal.fromJson(payloads['goal_kept'] as Map<String, dynamic>);

    expect(goal.isComplete, isTrue);
    expect(goal.fraction, 1.0);
    expect(goal.earnedWeeks, isNotEmpty);

    // Each prize carries what that week was spent on. Without the kind
    // the shelf is a row of identical tokens counting compliance, which
    // is the thing this feature is built not to be.
    for (final week in goal.earnedWeeks) {
      expect(week.kind, isNotNull);
    }
    expect(goal.earnedWeeks.map((w) => w.weekStart).toSet().length,
        goal.earnedWeeks.length,
        reason: 'the same week appeared twice on the shelf');
  });

  test('a message from home is announced but sealed until the week is kept',
      () {
    final goal = WeeklyGoal.fromJson(
        payloads['goal_promise_sealed'] as Map<String, dynamic>);
    final promise = goal.promise;

    expect(promise, isNotNull);
    expect(goal.isComplete, isFalse);
    // The child is told there is something and whose it is. That is what
    // makes it worth working towards rather than a surprise afterwards.
    expect(promise!.hasVoice, isTrue);
    expect(promise.parentName, isNotEmpty);
    expect(promise.isSealed, isTrue);
    // If this ever fails, a child can hear their parent's message without
    // finishing — which empties out the one moment the feature exists for.
    expect(promise.voiceUrl, isNull,
        reason: 'the recording was handed over before it was earned');
  });

  test('finishing the week opens the message', () {
    final goal = WeeklyGoal.fromJson(
        payloads['goal_promise_open'] as Map<String, dynamic>);
    final promise = goal.promise!;

    expect(goal.isComplete, isTrue);
    expect(promise.isSealed, isFalse);
    expect(promise.voiceUrl, isNotNull);
    expect(promise.text, isNotEmpty);
  });

  test('the dashboard tells a parent their child kept the week', () {
    // Parsed by the parent dashboard's own model, which read a
    // total_points field the server has never sent — every load threw.
    final row =
        payloads['parent_dashboard_child'] as Map<String, dynamic>;

    expect(row['kept_the_week'], isNotNull,
        reason: 'a parent who is not told has been made to break a promise');
    expect(row.containsKey('promise_text'), isTrue);
    expect(row.containsKey('promise_wanted'), isTrue);
    expect(row.containsKey('total_points'), isFalse,
        reason: 'the client must not go back to reading a field '
            'the server does not send');
  });

  test('the story payload parses and locked ones carry no text', () {
    final shelf =
        StoryShelf.fromJson(payloads['stories'] as Map<String, dynamic>);

    expect(shelf.stories, isNotEmpty);
    for (final story in shelf.stories) {
      expect(story.title, isNotEmpty);
      if (story.isUnlocked) {
        expect(story.content, isNotNull,
            reason: 'an unlocked story arrived with nothing to read');
      } else {
        // The server withholds it. If this ever fails, a child is being
        // shown text the app has judged too hard for them.
        expect(story.content, isNull,
            reason: 'a locked story leaked its text to the client');
        expect(story.blockingPhoneme, isNotNull,
            reason: 'a locked story gave the child nothing to aim at');
      }
    }
  });
}
