// Which letters a child is shown for a sound.
//
// This is not formatting. The app teaches sound-to-letter correspondence,
// so the letters on the screen *are* the lesson, and showing the wrong ones
// teaches the wrong thing with no error anywhere to say so.
//
// The screens used to render `symbol`, which is how the curriculum records
// a sound rather than how it is written. Eight of the first twenty-six
// stored something other than the letter, and four of those looked
// perfectly ordinary on screen.
import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/features/phonics/data/models/lesson_model.dart';
import 'package:phonics_app/features/phonics/domain/entities/lesson_entity.dart';

PhonemeEntity phoneme({
  required String symbol,
  String? graphemes,
  int order = 1,
}) =>
    PhonemeEntity(
      id: order,
      symbol: symbol,
      graphemes: graphemes,
      description: '',
      type: 'ALPHABET',
      order: order,
    );

void main() {
  group('the letters shown for a sound', () {
    test('a single letter is shown capital then small', () {
      expect(phoneme(symbol: 'Aa', graphemes: 'a').letterForms, ['A a']);
    });

    test('a digraph is one unit in both cases, not two letters', () {
      // `sh` is one sound. "S H" would be a lie about how it is read.
      expect(phoneme(symbol: 'ʃ (sh)', graphemes: 'sh').letterForms, ['SH sh']);
    });

    test('a sound spelled two ways shows both spellings', () {
      expect(
        phoneme(symbol: 'iː (ee/ea)', graphemes: 'ee,ea').letterForms,
        ['EE ee', 'EA ea'],
      );
    });

    test('spacing in the stored list does not reach the screen', () {
      expect(phoneme(symbol: 'x', graphemes: ' ee , ea ').letterForms,
          ['EE ee', 'EA ea']);
    });
  });

  group('the eight sounds the old rendering got wrong', () {
    // Every case here is real: symbol as stored in the seeded curriculum,
    // against the letter the child is actually learning.
    const cases = <String, List<String>>{
      // stored symbol : [grapheme, what the child must see]
      'ɪ': ['i', 'I i'],
      'dʒ': ['j', 'J j'],
      'kʰ': ['k', 'K k'],
      'ɒ/ɔ': ['o', 'O o'],
      'kw': ['q', 'Q q'],
      'ʌ/ə': ['u', 'U u'],
      'ks': ['x', 'X x'],
      'Jj': ['y', 'Y y'],
    };

    cases.forEach((symbol, expected) {
      test('$symbol is shown as ${expected[1]}', () {
        final p = phoneme(symbol: symbol, graphemes: expected[0]);
        expect(p.letterForms, [expected[1]]);
        expect(p.letters, expected[1]);
      });
    });

    test('the letter Y never renders as J', () {
      // The worst of them, because nothing looks broken: Y is stored with
      // the symbol "Jj", so a child learning Y was shown a confident,
      // ordinary-looking, wrong letter.
      final y = phoneme(symbol: 'Jj', graphemes: 'y', order: 25);
      expect(y.letters, isNot(contains('J')));
      expect(y.letters, 'Y y');
    });
  });

  group('the spelling survives the trip from the server', () {
    test('graphemes is read off the payload', () {
      final p = PhonemeModel.fromJson(const {
        'id': 10,
        'symbol': 'dʒ',
        'graphemes': 'j',
        'order': 10,
        'type': 'ALPHABET',
      });
      expect(p.letters, 'J j');
    });

    test('an older server that omits it shows nothing, not the symbol', () {
      // The field was added to PhonemeSummary; a deployment that predates
      // it must not fall back to putting IPA in front of a child.
      final p = PhonemeModel.fromJson(const {
        'id': 10,
        'symbol': 'dʒ',
        'order': 10,
        'type': 'ALPHABET',
      });
      expect(p.letterForms, isEmpty);
    });
  });

  group('when the curriculum has recorded no spelling', () {
    test('nothing is shown rather than the symbol', () {
      // Deliberately not a fallback to `symbol`. A blank space is obviously
      // wrong to anyone who looks; a wrong letter is not.
      expect(phoneme(symbol: 'dʒ').letterForms, isEmpty);
      expect(phoneme(symbol: 'dʒ', graphemes: '').letterForms, isEmpty);
      expect(phoneme(symbol: 'dʒ', graphemes: ' , ').letterForms, isEmpty);
      expect(phoneme(symbol: 'dʒ').letters, '');
    });
  });
}
