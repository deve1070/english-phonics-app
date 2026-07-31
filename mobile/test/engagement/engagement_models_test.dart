import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/features/engagement/data/engagement_models.dart';

void main() {
  group('DailyQuest', () {
    test('parses a full quest', () {
      final quest = DailyQuest.fromJson({
        'quest_date': '2026-07-31',
        'items': [
          {
            'slot': 'review',
            'exercise_id': 7,
            'content': 'cat',
            'type': 'word',
            'completed': true,
          },
          {
            'slot': 'stretch',
            'exercise_id': 9,
            'content': 'ship',
            'type': 'word',
            'completed': false,
          },
        ],
        'completed_count': 1,
        'total_count': 2,
        'is_complete': false,
      });

      expect(quest.items.map((i) => i.slot),
          [QuestSlot.review, QuestSlot.stretch]);
      expect(quest.completedCount, 1);
      expect(quest.isComplete, isFalse);
    });

    test('a quest with fewer than three items is normal, not an error', () {
      // The server leaves a slot empty when the curriculum cannot fill it
      // rather than padding with a repeat, so nothing may assume three.
      final quest = DailyQuest.fromJson({
        'quest_date': '2026-07-31',
        'items': [
          {'slot': 'current', 'exercise_id': 1, 'content': 'a', 'type': 'phoneme'},
        ],
        'completed_count': 0,
        'is_complete': false,
      });
      expect(quest.items, hasLength(1));
      expect(quest.isEmpty, isFalse);
    });

    test('an unknown slot falls back to current rather than throwing', () {
      // A client older than the server must degrade, not crash.
      final item = QuestItem.fromJson({
        'slot': 'something_new',
        'exercise_id': 1,
        'content': 'a',
      });
      expect(item.slot, QuestSlot.current);
    });

    test('no slot label names a deficit', () {
      // The review slot picks the child's weakest sound. Saying so is
      // exactly what we must not do.
      for (final slot in QuestSlot.values) {
        expect(slot.label.toLowerCase(), isNot(contains('weak')));
        expect(slot.label.toLowerCase(), isNot(contains('wrong')));
        expect(slot.label.toLowerCase(), isNot(contains('bad')));
      }
    });
  });

  group('StreakInfo', () {
    test('a short run is not shown at all', () {
      // A counter at 1 tells a child who just started that they have
      // almost nothing.
      for (var days = 0; days < StreakInfo.showFrom; days++) {
        expect(
          StreakInfo(days: days, freezesAvailable: 0, frozenDates: const [])
              .isWorthShowing,
          isFalse,
          reason: '$days days should stay hidden',
        );
      }
    });

    test('the run appears once it is worth protecting', () {
      expect(
        const StreakInfo(
                days: StreakInfo.showFrom,
                freezesAvailable: 0,
                frozenDates: [])
            .isWorthShowing,
        isTrue,
      );
    });

    test('a frozen day is reported, not hidden', () {
      final streak = StreakInfo.fromJson({
        'days': 5,
        'freezes_available': 0,
        'frozen_dates': ['2026-07-30'],
      });
      expect(streak.wasSaved, isTrue);
      expect(streak.frozenDates.single, DateTime.parse('2026-07-30'));
    });

    test('an unbroken run reports no rescue', () {
      final streak = StreakInfo.fromJson({
        'days': 5,
        'freezes_available': 1,
        'frozen_dates': <String>[],
      });
      expect(streak.wasSaved, isFalse);
      expect(streak.freezesAvailable, 1);
    });
  });

  group('Story', () {
    test('a locked story arrives without its text', () {
      final story = Story.fromJson({
        'exercise_id': 3,
        'title': 'The cat sat',
        'word_count': 12,
        'is_unlocked': false,
        'blocking_phoneme': 'Cc',
      });
      expect(story.content, isNull);
      expect(story.blockingPhoneme, 'Cc');
    });

    test('an open story carries its text', () {
      final story = Story.fromJson({
        'exercise_id': 3,
        'title': 'The cat sat',
        'word_count': 12,
        'is_unlocked': true,
        'content': 'The cat sat on a mat.',
      });
      expect(story.content, 'The cat sat on a mat.');
    });
  });

  group('Collection', () {
    test('locked collectibles are part of the list', () {
      // The gaps are the point — a shelf that only showed what you had
      // would give a child nothing to aim at.
      final collection = Collection.fromJson({
        'total': 2,
        'unlocked': 1,
        'items': [
          {
            'phoneme_id': 1,
            'symbol': 'Aa',
            'order': 1,
            'phoneme_type': 'alphabet',
            'is_unlocked': true,
            'is_new': true,
          },
          {
            'phoneme_id': 2,
            'symbol': 'Bb',
            'order': 2,
            'phoneme_type': 'alphabet',
            'is_unlocked': false,
          },
        ],
        'newly_unlocked': [1],
      });

      expect(collection.items, hasLength(2));
      expect(collection.items.where((c) => c.isUnlocked), hasLength(1));
      expect(collection.newlyUnlocked, [1]);
    });
  });
}
