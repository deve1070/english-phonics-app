import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/entities/exercise_entity.dart';

class ExerciseCard extends StatelessWidget {
  final ExerciseEntity exercise;
  final Color color;
  final VoidCallback onTap;
  final int lessonId;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.color,
    required this.onTap,
    required this.lessonId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                _iconForType(exercise.type),
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _labelForType(exercise.type),
                    style: AppTextStyles.label.copyWith(color: color),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    exercise.content,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontFamily: 'PatrickHand',
                      fontSize: 20,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Difficulty dots + arrow
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: List.generate(
                    3,
                    (i) => Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(left: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < exercise.difficulty
                            ? color
                            : color.withOpacity(0.2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textSecondary,
                  size: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'WORD':
        return Icons.text_fields_rounded;
      case 'SENTENCE':
        return Icons.short_text_rounded;
      case 'PARAGRAPH':
        return Icons.article_rounded;
      case 'PHONEME':
        return Icons.record_voice_over_rounded;
      default:
        return Icons.text_fields_rounded;
    }
  }

  String _labelForType(String type) {
    switch (type) {
      case 'WORD':
        return 'WORD PRACTICE';
      case 'SENTENCE':
        return 'SENTENCE';
      case 'PARAGRAPH':
        return 'PARAGRAPH';
      case 'PHONEME':
        return 'PHONEME DRILL';
      default:
        return type;
    }
  }
}
