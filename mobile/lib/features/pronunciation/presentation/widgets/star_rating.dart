import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

/// Converts a pronunciation score into stars.
///
/// Children never see the raw number. A percentage is a grade — it invites
/// a child to read themselves as "a 44" — whereas stars are a target you
/// collect and can go back for. The thresholds are the ones the app already
/// used for pass/good/perfect, so this is a change of presentation, not of
/// standard. The number stays on parent-facing surfaces, where it is
/// diagnostic rather than judgemental.
int starsForScore(double score) {
  if (score >= ScoreThresholds.perfect) return 3;
  if (score >= ScoreThresholds.good) return 2;
  if (score >= ScoreThresholds.pass) return 1;
  return 0;
}

class StarRating extends StatelessWidget {
  final int stars;
  final double size;

  /// Animates each star in with a pop. Off for static/summary contexts.
  final bool animate;

  const StarRating({
    super.key,
    required this.stars,
    this.size = 44,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final earned = i < stars;
        final star = Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.08),
          child: Icon(
            earned ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            // Unearned stars are drawn in a dormant neutral, never in red.
            // An empty slot should read as "still available", not as a
            // mark against the child.
            color: earned ? AppColors.honey : AppColors.dormant,
          ),
        );

        if (!animate || !earned) return star;
        // Stagger so three stars land as three separate beats rather than
        // one lump — the rhythm is most of the reward.
        return star
            .animate(delay: Duration(milliseconds: 220 * i))
            .scale(
              begin: const Offset(0.3, 0.3),
              end: const Offset(1, 1),
              duration: 420.ms,
              curve: Curves.elasticOut,
            )
            .fadeIn(duration: 180.ms);
      }),
    );
  }
}
