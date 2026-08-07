import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/mascot/kiki.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';

/// The end of the day's sequence.
///
/// The app plays the day for the child, and something that plays has to
/// stop. Without this screen the sequence would simply run out and drop
/// them somewhere, which reads as the app losing its place rather than as
/// an ending — and an app that never says "that's everything" teaches a
/// child that there is always more owed.
///
/// So: nothing to do here, and nothing offered. No "one more round", no
/// count of what is left, no tomorrow's target. One quiet way out.
class DayDoneScreen extends StatelessWidget {
  const DayDoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Kiki(size: 200, mood: KikiMood.celebrating)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1, 1),
                      duration: 500.ms,
                      curve: Curves.elasticOut,
                    ),
                const SizedBox(height: AppSpacing.xl),

                // Past tense, and about the child rather than about a
                // score. What they get told is that they finished, because
                // that is the thing worth believing about themselves.
                Text(
                  'You did everything today!',
                  style: AppTextStyles.headingMedium,
                  textAlign: TextAlign.center,
                ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: AppSpacing.sm),

                Text(
                  'A new sound is waiting tomorrow.',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ).animate(delay: 350.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: AppSpacing.xxl),

                // Deliberately not "keep going". The way on from here is
                // out of the day, to Me — their sounds, their stories,
                // their name. Those are a reward for having finished, not
                // a fourth task dressed as one, and the stories are the
                // one thing a child is meant to be able to go back to
                // freely.
                TextButton(
                  onPressed: () => context.go(AppRoutes.profile),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.teal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.md,
                    ),
                  ),
                  child: Text(
                    'See my things',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ).animate(delay: 700.ms).fadeIn(duration: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
