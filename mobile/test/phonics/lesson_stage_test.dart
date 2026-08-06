// Resolving a stored stage name back into a step.
//
// These names are written into the resume cursor and read back at launch,
// possibly by a different build of the app than the one that wrote them.
// Whatever comes back has to land somewhere a child can carry on from:
// this runs before anything is on screen, for a child who cannot navigate
// their way out of a wrong answer.
import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/features/phonics/presentation/screens/lesson_stage.dart';

void main() {
  group('every real stage resolves to itself', () {
    for (final stage in LessonStage.values) {
      test(stage.name, () {
        expect(LessonStage.named(stage.name), stage);
      });
    }
  });

  group('anything else starts the sound again', () {
    const start = LessonStage.phonemeIntro;

    test('a name from a build that had different steps', () {
      expect(LessonStage.named('watchTheMouth'), start);
      expect(LessonStage.named('tracing'), start);
    });

    test('nothing at all', () {
      expect(LessonStage.named(null), start);
      expect(LessonStage.named(''), start);
    });

    test('the right word in the wrong case', () {
      // Names are compared exactly. Worth pinning so a change to the
      // comparison is a decision rather than an accident.
      expect(LessonStage.named('Gate'), start);
      expect(LessonStage.named('GATE'), start);
    });

    test('rubbish', () {
      expect(LessonStage.named('   '), start);
      expect(LessonStage.named('{"stage":"gate"}'), start);
    });
  });

  test('the first stage is the one a lesson opens on', () {
    // The fallback is only safe because starting here is always valid.
    expect(LessonStage.values.first, LessonStage.phonemeIntro);
  });
}
