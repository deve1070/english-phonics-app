import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/features/engagement/presentation/widgets/week_medal.dart';

/// A week's prize is derived from the week itself, with no artwork and no
/// server involvement. Two properties make that worth doing, and both are
/// promises to the child rather than implementation details:
///
///   the medal shown greyed on Monday is the one handed over on Friday,
///   and last week's is not mistakable for this week's on the shelf.
void main() {
  DateTime monday(int weeksFromEpochMonday) =>
      DateTime.utc(1970, 1, 5).add(Duration(days: 7 * weeksFromEpochMonday));

  group('MedalTraits', () {
    test('a week always produces the same medal', () {
      // Across devices and reinstalls. If this drifted, a child working
      // towards the prize they were shown on Monday would be handed a
      // different one — which makes the whole "you can see it from the
      // start" arrangement a lie.
      final week = monday(2900);
      expect(MedalTraits.forWeek(week), MedalTraits.forWeek(week));
      expect(
        MedalTraits.forWeek(week),
        MedalTraits.forWeek(week.toLocal()),
        reason: 'the medal changed with the timezone it was drawn in',
      );
    });

    test('consecutive weeks never share a medal', () {
      // These are the two that sit next to each other on the shelf.
      for (var w = 2800; w < 3100; w++) {
        expect(
          MedalTraits.forWeek(monday(w)),
          isNot(MedalTraits.forWeek(monday(w + 1))),
          reason: 'weeks $w and ${w + 1} produced the same medal',
        );
      }
    });

    test('a run of weeks is visibly varied', () {
      // A whole term on one shelf. Ribbon colour is what the eye sorts
      // on, so it must not settle into two shades for months.
      for (var start = 2800; start < 3000; start++) {
        final term = [for (var w = start; w < start + 5; w++) MedalTraits.forWeek(monday(w))];
        expect(
          term.map((t) => t.ribbon).toSet().length,
          greaterThanOrEqualTo(4),
          reason: 'the five weeks from $start are nearly one colour',
        );
      }
    });

    test('a school year does not run out of medals', () {
      final year = [for (var w = 2900; w < 2952; w++) MedalTraits.forWeek(monday(w))];
      expect(MedalTraits.variants, greaterThanOrEqualTo(12));
      // Repeats across a year are fine — nobody holds week 3 and week 40
      // side by side — but not so many that a shelf looks copy-pasted.
      expect(year.toSet().length, greaterThanOrEqualTo(12));
    });
  });
}
