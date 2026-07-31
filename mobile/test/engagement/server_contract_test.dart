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
