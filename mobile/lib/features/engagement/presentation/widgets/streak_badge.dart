import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/engagement_models.dart';

/// The practice run, shown only once there is a run to show.
///
/// Below [StreakInfo.showFrom] this renders nothing at all. A counter
/// sitting at 0 or 1 is the least motivating thing a screen can contain —
/// it tells a child who has just started that they have almost nothing,
/// which is the opposite of what the first week needs to say. The streak
/// appears when it has become worth protecting.
///
/// When a freeze is holding the run together the badge says so rather
/// than pretending the child practised that day. Being told "we kept it
/// for you" is a kindness the child can understand; a number that quietly
/// fails to break teaches them the number is fake.
class StreakBadge extends StatelessWidget {
  final StreakInfo streak;

  /// Compact form for the greeting header; the long form explains itself.
  final bool compact;

  const StreakBadge({super.key, required this.streak, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (!streak.isWorthShowing) return const SizedBox.shrink();

    final label = '${streak.days}';
    return Semantics(
      label: streak.wasSaved
          ? '${streak.days} day streak, saved by a freeze'
          : '${streak.days} day streak',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.sm + 2 : AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: streak.wasSaved ? AppColors.skyLight : AppColors.honeyLight,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: streak.wasSaved ? AppColors.sky : AppColors.honey,
            width: AppBorders.standard,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              streak.wasSaved
                  ? Icons.ac_unit_rounded
                  : Icons.local_fire_department_rounded,
              size: compact ? 16 : 20,
              color: streak.wasSaved ? AppColors.sky : AppColors.honey,
            ),
            const SizedBox(width: 4),
            Text(
              compact ? label : '$label day${streak.days == 1 ? '' : 's'}',
              style: AppTextStyles.label.copyWith(
                color: AppColors.ink,
                fontSize: compact ? 13 : 15,
              ),
            ),
            if (!compact && streak.wasSaved) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(
                '· we kept it for you',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.sky),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
