// Visual preview. Regenerate:
//   flutter test --update-goldens test/lessons/journey_map_preview_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/core/theme/app_colors.dart';
import 'package:phonics_app/core/theme/app_theme.dart';
import 'package:phonics_app/features/lessons/presentation/widgets/journey_map.dart';
import 'package:phonics_app/features/phonics/domain/entities/lesson_entity.dart';

import '../support/preview_fonts.dart';

LessonEntity lesson(int i, String sym, String level, int done, int total) =>
    LessonEntity(
      id: i, order: i, level: level, totalExercises: total,
      completedExercises: done,
      phonemes: [PhonemeEntity(
        id: i, symbol: sym, description: '', type: 'consonant', order: i)],
    );

void main() {
  setUpAll(loadPreviewFonts);

  testWidgets('journey map', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    final lessons = [
      lesson(1, 'Aa', 'LEVEL1', 4, 4),
      lesson(2, 'Bb', 'LEVEL1', 3, 3),
      lesson(3, 'Cc', 'LEVEL1', 1, 4),   // current
      lesson(4, 'Dd', 'LEVEL2', 0, 4),   // locked
      lesson(5, 'Ee', 'LEVEL2', 0, 4),
      lesson(6, 'Ff', 'LEVEL3', 0, 4),
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
