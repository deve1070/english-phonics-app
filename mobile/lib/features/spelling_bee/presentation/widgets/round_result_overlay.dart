import 'package:flutter/material.dart';
import '../../../../core/mascot/kiki.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../cubit/spelling_bee_state.dart';

class RoundResultOverlay extends StatelessWidget {
  final SpellingBeeResult state;
  final VoidCallback onNext;

  const RoundResultOverlay({
    super.key,
    required this.state,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect = state.isCorrect;
    final color = isCorrect ? AppColors.green : AppColors.coral;

    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadows.floating,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A wrong answer gets her leaning in, not sulking: the mood
              // answers the effort, never the score.
              Kiki(
                size: 100,
                mood: isCorrect ? KikiMood.celebrating : KikiMood.encouraging,
              ).animate().scale(
                    begin: const Offset(0.5, 0.5),
                    duration: 500.ms,
                    curve: Curves.elasticOut,
                  ),

              const SizedBox(height: AppSpacing.md),

              Text(
                isCorrect ? 'Correct! 🎉' : 'Not quite...',
                style: AppTextStyles.displaySmall.copyWith(color: color),
              ).animate(delay: 200.ms).fadeIn(duration: 300.ms),

              const SizedBox(height: AppSpacing.sm),

              // Show correct word if wrong
              if (!isCorrect) ...[
                Text('The word was:', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  state.word.toUpperCase(),
                  style: AppTextStyles.displaySmall.copyWith(
                    color: AppColors.teal,
                    fontFamily: 'PatrickHand',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Score + difficulty badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      'Score: ${state.score} / ${state.round}',
                      style: AppTextStyles.headingSmall.copyWith(color: color),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs + 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.purple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      state.difficulty.label,
                      style: AppTextStyles.label
                          .copyWith(color: AppColors.purple, fontSize: 11),
                    ),
                  ),
                ],
              ).animate(delay: 300.ms).fadeIn(duration: 300.ms),

              const SizedBox(height: AppSpacing.xl),

              SizedBox(
                width: double.infinity,
                height: AppSizes.minTouchTarget,
                child: ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    state.isFinalRound ? 'See Results! 🏆' : 'Next Word →',
                    style: AppTextStyles.buttonLarge,
                  ),
                ),
              ).animate(delay: 400.ms).fadeIn(duration: 300.ms),
            ],
          ),
        )
            .animate()
            .scale(
              begin: const Offset(0.8, 0.8),
              duration: 400.ms,
              curve: Curves.elasticOut,
            )
            .fadeIn(duration: 300.ms),
      ),
    );
  }
}
