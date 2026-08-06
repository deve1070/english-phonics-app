// Visual preview. Regenerate:
//   flutter test --update-goldens test/lessons/journey_map_preview_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/core/theme/app_colors.dart';
import 'package:phonics_app/core/theme/app_theme.dart';
import 'package:phonics_app/features/lessons/presentation/widgets/journey_map.dart';
import 'package:phonics_app/features/phonics/domain/entities/lesson_entity.dart';

import '../support/preview_fonts.dart';

/// [sym] is how the curriculum records the sound, [spelling] how it is
/// written. They are given separately and differently on purpose: a stop on
/// the map is labelled with the letter a child can read, never with the
/// symbol, and passing "Aa" for both would hide it if that ever changed.
LessonEntity lesson(
  int i,
  String sym,
  String spelling,
  String level,
  int done,
  int total,
) =>
    LessonEntity(
      id: i, order: i, level: level, totalExercises: total,
      completedExercises: done,
      phonemes: [PhonemeEntity(
        id: i, symbol: sym, graphemes: spelling,
        description: '', type: 'consonant', order: i)],
    );

void main() {
  setUpAll(loadPreviewFonts);

  testWidgets('journey map', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    final lessons = [
      lesson(1, 'Aa', 'a', 'LEVEL1', 4, 4),
      lesson(2, 'Bb', 'b', 'LEVEL1', 3, 3),
      lesson(3, 'Cc', 'c', 'LEVEL1', 1, 4),   // current
      // Stored as IPA. The map must label this stop "j", not "dʒ".
      lesson(4, 'dʒ', 'j', 'LEVEL2', 0, 4),   // locked
      lesson(5, 'Ee', 'e', 'LEVEL2', 0, 4),
      lesson(6, 'ʃ (sh)', 'sh', 'LEVEL3', 0, 4),
    ];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: Material(
        color: AppColors.parchment,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: JourneyMap(lessons: lessons, onTapLesson: (_) {}),
        ),
      ),
    ));
    await settleAnimations(tester, total: const Duration(milliseconds: 900));
    await expectLater(find.byType(JourneyMap), matchesGoldenFile('journey_map.png'));
  });
}
