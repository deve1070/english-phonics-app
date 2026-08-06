import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/mascot/kiki.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../cubit/spelling_bee_state.dart';

class SpellingBeeFinalScreen extends StatelessWidget {
  final SpellingBeeDone state;
  final VoidCallback onPlayAgain;
  final VoidCallback onGoHome;

  const SpellingBeeFinalScreen({
    super.key,
    required this.state,
    required this.onPlayAgain,
    required this.onGoHome,
  });

  Color get _color {
    if (state.percentage >= 0.8) return AppColors.green;
    if (state.percentage >= 0.6) return AppColors.teal;
    return AppColors.coral;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Confetti-like circles
          ..._buildConfetti(),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.xl),

                  // Trophy + mascot
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _color.withOpacity(0.12),
                        ),
                      ),
                      Kiki(
                        size: 140,
                        mood: state.percentage >= 0.6
                            ? KikiMood.celebrating
                            : KikiMood.encouraging,
                      ),
                    ],
                  ).animate().scale(
                        begin: const Offset(0.5, 0.5),
                        duration: 700.ms,
                        curve: Curves.elasticOut,
                      ),

                  const SizedBox(height: AppSpacing.xl),

                  Text(
                    state.grade,
                    style: AppTextStyles.displayMedium.copyWith(
                      color: _color,
                    ),
                    textAlign: TextAlign.center,
                  )
                      .animate(delay: 300.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.2, end: 0),

                  const SizedBox(height: AppSpacing.xl),

                  // Score card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      boxShadow: AppShadows.card,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Your Score',
                          style: AppTextStyles.label,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${state.finalScore}',
                              style: AppTextStyles.displayLarge.copyWith(
                                color: _color,
                                fontSize: 72,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                ' / ${state.totalRounds}',
                                style: AppTextStyles.displaySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Star rating
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (i) {
                            final filled = i < (state.percentage * 5).round();
                            return Icon(
                              filled
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color:
                                  filled ? AppColors.yellow : AppColors.border,
                              size: 36,
                            )
                                .animate(
                                  delay: Duration(milliseconds: 500 + i * 100),
                                )
                                .scale(
                                  begin: const Offset(0.5, 0.5),
                                  duration: 300.ms,
                                  curve: Curves.elasticOut,
                                );
                          }),
                        ),
                      ],
                    ),
                  ).animate(delay: 400.ms).fadeIn(duration: 400.ms),

                  const SizedBox(height: AppSpacing.xl),

                  // Play again
                  SizedBox(
                    width: double.infinity,
                    height: AppSizes.minTouchTarget,
                    child: ElevatedButton.icon(
                      onPressed: onPlayAgain,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Play Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        elevation: 0,
                        textStyle: AppTextStyles.buttonLarge,
                      ),
                    ),
                  ).animate(delay: 600.ms).fadeIn(duration: 400.ms),

                  const SizedBox(height: AppSpacing.md),

                  // Go home
                  SizedBox(
                    width: double.infinity,
                    height: AppSizes.minTouchTarget,
                    child: OutlinedButton.icon(
                      onPressed: onGoHome,
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('Go Home'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(
                          color: AppColors.border,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        minimumSize: const Size(
                            double.infinity, AppSizes.minTouchTarget),
                      ),
                    ),
                  ).animate(delay: 700.ms).fadeIn(duration: 400.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildConfetti() {
    final rng = Random(42);
    final colors = [
      AppColors.coral,
      AppColors.teal,
      AppColors.yellow,
      AppColors.purple,
      AppColors.green,
    ];
    return List.generate(12, (i) {
      final color = colors[i % colors.length];
      return Positioned(
        top: rng.nextDouble() * 700,
        left: rng.nextDouble() * 400,
        child: Container(
          width: 10 + rng.nextDouble() * 16,
          height: 10 + rng.nextDouble() * 16,
          decoration: BoxDecoration(
            shape: rng.nextBool() ? BoxShape.circle : BoxShape.rectangle,
            color: color.withOpacity(0.25),
          ),
        )
            .animate(
              delay: Duration(milliseconds: i * 80),
              onPlay: (c) => c.repeat(reverse: true),
            )
            .moveY(
              begin: 0,
              end: -12,
              duration: Duration(milliseconds: 1200 + i * 100),
              curve: Curves.easeInOut,
            ),
      );
    });
  }
}
