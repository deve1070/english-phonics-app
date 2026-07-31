import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/features/pronunciation/domain/word_alignment.dart';

List<String> saidWords(List<WordResult> r) =>
    r.where((w) => w.outcome == WordOutcome.said).map((w) => w.word).toList();

List<String> missedWords(List<WordResult> r) =>
    r.where((w) => w.outcome == WordOutcome.missed).map((w) => w.word).toList();

void main() {
  group('alignWords', () {
    test('a perfect reading marks every word said', () {
      final r = alignWords(expected: 'The cat sat', heard: 'the cat sat');
      expect(missedWords(r), isEmpty);
      expect(saidWords(r), ['The', 'cat', 'sat']);
    });

    test('punctuation and case are not pronunciation errors', () {
      final r = alignWords(expected: 'The cat sat.', heard: 'The, cat! SAT');
      expect(missedWords(r), isEmpty);
    });

    test('preserves the original spelling for display', () {
      final r = alignWords(expected: 'The CAT sat.', heard: 'the cat sat');
      expect(r.map((w) => w.word).toList(), ['The', 'CAT', 'sat.']);
    });

    test('a dropped word does not shift everything after it out of line', () {
      // The failure mode of index-by-index comparison: drop one early word
      // and every later word mismatches, turning a good read into a zero.
      final r = alignWords(
        expected: 'the big cat sat on a mat',
        heard: 'the cat sat on a mat',
      );
      expect(missedWords(r), ['big']);
      expect(saidWords(r).length, 6);
    });

    test('inserted words are ignored rather than penalised', () {
      final r = alignWords(
        expected: 'the cat sat',
        heard: 'um the uh cat sat',
      );
      expect(missedWords(r), isEmpty);
    });

    test('a repeated word is not credited twice', () {
      // "the the cat" must not let the duplicate satisfy a later word.
      final r = alignWords(expected: 'the cat the dog', heard: 'the the cat');
      expect(saidWords(r), ['the', 'cat']);
      expect(missedWords(r), ['the', 'dog']);
    });

    test('silence marks every word missed, none said', () {
      final r = alignWords(expected: 'the cat sat', heard: '');
      expect(saidWords(r), isEmpty);
      expect(missedWords(r).length, 3);
    });

    test('completely different speech marks all words missed', () {
      final r = alignWords(expected: 'the cat sat', heard: 'hello world');
      expect(saidWords(r), isEmpty);
    });

    test('empty expected text yields no results', () {
      expect(alignWords(expected: '   ', heard: 'anything'), isEmpty);
    });

    test('handles a single word exercise', () {
      expect(missedWords(alignWords(expected: 'cat', heard: 'Cat.')), isEmpty);
      expect(saidWords(alignWords(expected: 'cat', heard: 'dog')), isEmpty);
    });
  });
}
