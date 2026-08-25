import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../phonics/domain/entities/lesson_entity.dart';
import 'level_style.dart';

class LessonCard extends StatelessWidget {
  final LessonEntity lesson;
  final VoidCallback onTap;
  final int index;

  const LessonCard({
    super.key,
    required this.lesson,
    required this.onTap,
    required this.index,
  });

  /// The spellings this lesson teaches, as a glance.
  ///
  /// This card is a label for a lesson, not the screen that teaches it, so
  /// it lists the spellings only — the small-and-capital pair belongs on
  /// the sound's own screen, where both cases are the thing being learnt.
  ///
  /// Read straight off `spellings`. Deriving it from `symbol` with a regex
  /// puts "D3" and "Kw" in front of children learning J and Q.
  String _getPhonemesDisplay() =>
      lesson.phonemes.expand((p) => p.spellings).join('  ');

  @override
  Widget build(BuildContext context) {
    final color = LevelStyle.color(lesson.level);
    final isLocked = index > 0 && !lesson.isStarted;
    final phonemesDisplay = _getPhonemesDisplay();

    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: AnimatedOpacity(
        opacity: isLocked ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: lesson.isCompleted
                  ? color.withValues(alpha: 0.4)
                  : AppColors.border,
              width: lesson.isCompleted ? 2 : 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowLight,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row — emoji + lock/check
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Center(
                      child: Text(
                        LevelStyle.emoji(lesson.level),
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  _StatusBadge(lesson: lesson, color: color),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // Phoneme symbols - huge & kid friendly!
              Text(
                phonemesDisplay,
                style: AppTextStyles.headingLarge.copyWith(
                  color: color,
                  fontSize: 50,
                  fontFamily: 'PatrickHand',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // No "Level 1 · 5 sounds" line. It reports on the
              // curriculum rather than anything a child can act on, and the
              // three or four pixels it takes push this card past the 190
              // it is given, striping every one of them with an overflow
              // warning.
              const Spacer(),

              if (lesson.isStarted || lesson.isCompleted) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: lesson.progressPercent,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(lesson.progressPercent * 100).toInt()}%',
                  style: AppTextStyles.label.copyWith(
                    color: color,
                    fontSize: 11,
                  ),
                ),
              ] else ...[
                Text(
                  isLocked ? '🔒 Complete previous' : 'Tap to start!',
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final LessonEntity lesson;
  final Color color;

  const _StatusBadge({required this.lesson, required this.color});

  @override
  Widget build(BuildContext context) {
    if (lesson.isCompleted) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: AppColors.green,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
      );
    }
    if (lesson.isStarted) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Icon(Icons.play_arrow_rounded, color: color, size: 16),
      );
    }
    return const SizedBox(width: 28, height: 28);
  }
}
