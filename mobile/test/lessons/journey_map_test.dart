import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/features/lessons/presentation/widgets/journey_map.dart';
import 'package:phonics_app/features/phonics/domain/entities/lesson_entity.dart';

LessonEntity lesson({required int done, required int total}) => LessonEntity(
      id: 1,
      order: 1,
      level: 'LEVEL1',
      phonemes: const [],
      totalExercises: total,
      completedExercises: done,
    );

void main() {
  group('JourneyMap.unlockedFlags', () {
    test('the first lesson is always open', () {
      final flags = JourneyMap.unlockedFlags([lesson(done: 0, total: 4)]);
      expect(flags, [true]);
    });

    test('a lesson opens only once the one before it is finished', () {
      final flags = JourneyMap.unlockedFlags([
        lesson(done: 4, total: 4), // complete
        lesson(done: 1, total: 4), // open, in progress
        lesson(done: 0, total: 4), // locked
        lesson(done: 0, total: 4), // locked
      ]);
      expect(flags, [true, true, false, false]);
    });

    test('an empty lesson does not wall off the rest of the curriculum', () {
      // Regression guard. A lesson with no exercises can never be
      // "completed", so gating purely on isCompleted would leave every
      // later lesson permanently locked whenever generated content is
      // missing — which is exactly the state the curriculum is in while
      // exercises are still being filled in.
      final flags = JourneyMap.unlockedFlags([
        lesson(done: 4, total: 4),
        lesson(done: 0, total: 0), // no content yet
        lesson(done: 0, total: 4),
      ]);
      expect(flags, [true, true, true]);
    });

    test('a part-finished lesson still blocks the next one', () {
      final flags = JourneyMap.unlockedFlags([
        lesson(done: 3, total: 4),
        lesson(done: 0, total: 4),
      ]);
      expect(flags, [true, false]);
    });

    test('handles an empty curriculum', () {
      expect(JourneyMap.unlockedFlags([]), isEmpty);
    });
  });
}
