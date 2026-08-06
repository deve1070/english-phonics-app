// The home screen gives every lesson card exactly 190 logical pixels. Its
// contents were three or four taller than that, so every card on the phonics
// path carried a yellow-and-black overflow stripe reading "BOTTOM OVERFLOWED
// BY 3.0 PIXELS" across the child's screen.
//
// Overflow is a layout error rather than a thrown one, so nothing failed and
// nothing logged; it was only visible by looking. This looks.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/features/home/presentation/widgets/lesson_card.dart';
import 'package:phonics_app/features/phonics/domain/entities/lesson_entity.dart';

/// The height home_screen.dart pins each card to.
const double kCardHeight = 190;

LessonEntity lesson({
  required List<(String symbol, String spelling)> sounds,
  int done = 2,
  int total = 4,
}) =>
    LessonEntity(
      id: 1,
      order: 1,
      level: 'LEVEL1',
      totalExercises: total,
      completedExercises: done,
      phonemes: [
        for (final (i, s) in sounds.indexed)
          PhonemeEntity(
            id: i,
            symbol: s.$1,
            graphemes: s.$2,
            description: '',
            type: 'ALPHABET',
            order: i + 1,
          ),
      ],
    );

Future<void> pumpCard(WidgetTester tester, LessonEntity l) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          height: kCardHeight,
          child: LessonCard(lesson: l, onTap: () {}, index: 0),
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('a card fits the height it is given', (tester) async {
    await pumpCard(
      tester,
      lesson(sounds: const [
        ('Aa', 'a'),
        ('Bb', 'b'),
        ('Cc', 'c'),
        ('Dd', 'd'),
        ('Ee', 'e'),
      ]),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a card of digraphs also fits', (tester) async {
    // Longer spellings, so the widest realistic case is covered too.
    await pumpCard(
      tester,
      lesson(sounds: const [
        ('ʃ (sh)', 'sh'),
        ('tʃ (ch)', 'ch'),
        ('ð (th)', 'th'),
        ('iː (ee/ea)', 'ee,ea'),
      ]),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unstarted card fits, having no progress bar',
      (tester) async {
    await pumpCard(tester, lesson(sounds: const [('Aa', 'a')], done: 0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the card shows spellings, never the curriculum symbol',
      (tester) async {
    // Y is stored with the symbol "Jj". A card rendering symbols put the
    // letter J in front of a child learning Y.
    await pumpCard(
      tester,
      lesson(sounds: const [('Jj', 'y'), ('dʒ', 'j'), ('kw', 'q')]),
    );
    expect(find.text('y  j  q'), findsOneWidget);
  });
}
