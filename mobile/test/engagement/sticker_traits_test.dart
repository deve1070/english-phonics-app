import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/features/engagement/presentation/widgets/sound_sticker.dart';

/// The collectibles carry no artwork — each creature is derived from its
/// phoneme id. That only works if the derivation actually spreads, so the
/// properties below are the feature's real contract.
void main() {
  group('StickerTraits', () {
    test('the same sound always gives the same creature', () {
      // Across devices, installs and reinstalls. If this drifted, a child
      // would come back to find their collection full of strangers.
      expect(StickerTraits.forPhoneme(42), StickerTraits.forPhoneme(42));
    });

    test('neighbouring sounds never share a creature', () {
      for (var id = 1; id < 200; id++) {
        expect(
          StickerTraits.forPhoneme(id),
          isNot(StickerTraits.forPhoneme(id + 1)),
          reason: 'phonemes $id and ${id + 1} produced the same creature',
        );
      }
    });

    test('a whole lesson is visibly varied', () {
      // Phoneme ids run consecutively and lessons hold five of them, so
      // this is the run a child actually sees side by side.
      for (var start = 1; start <= 86; start++) {
        final lesson = [
          for (var i = start; i < start + 5; i++) StickerTraits.forPhoneme(i)
        ];
        expect(
          lesson.toSet(),
          hasLength(5),
          reason: 'lesson starting at $start repeats a creature',
        );
        // Colour is what the eye sorts on: at least four shades in five.
        expect(
          lesson.map((t) => t.hue).toSet().length,
          greaterThanOrEqualTo(4),
          reason: 'lesson starting at $start is nearly one colour',
        );
      }
    });

    test('the whole curriculum fits inside the space of creatures', () {
      // Ninety sounds drawn from 240 combinations. Collisions between
      // distant sounds are acceptable — nobody sees phoneme 3 and phoneme
      // 67 together — but the curriculum must not exhaust the space.
      expect(StickerTraits.variants, greaterThan(90));
    });

    test('every axis is exercised across the curriculum', () {
      final traits = [for (var i = 1; i <= 90; i++) StickerTraits.forPhoneme(i)];
      expect(traits.map((t) => t.hue).toSet(), hasLength(5));
      expect(traits.map((t) => t.silhouette).toSet(), hasLength(4));
      expect(traits.map((t) => t.crown).toSet(), hasLength(3));
      expect(traits.map((t) => t.marking).toSet(), hasLength(4));
    });
  });
}
