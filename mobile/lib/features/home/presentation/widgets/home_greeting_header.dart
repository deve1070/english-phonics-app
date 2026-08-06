import 'package:flutter/material.dart';
import '../../../../core/mascot/kiki.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';

class HomeGreetingHeader extends StatelessWidget {
  final String name;
  final int streakDays;

  const HomeGreetingHeader({
    super.key,
    required this.name,
    required this.streakDays,
  });

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text side
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting,',
                  style: AppTextStyles.bodyMedium,
                ).animate().fadeIn(duration: 400.ms),
                Text(
                  name.split(' ').first, // first name only
                  style: AppTextStyles.displayMedium.copyWith(
                    color: AppColors.coral,
                  ),
                )
                    .animate(delay: 100.ms)
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: -0.1, end: 0, duration: 400.ms),
                const SizedBox(height: AppSpacing.sm),
                // Streak + points chips
                Row(
                  children: [
                    _StatChip(
                      icon: '🔥',
                      label: '$streakDays day streak',
                      color: AppColors.coral,
                    ),
                    ],
                ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
              ],
            ),
          ),
          // Same bird either way — a streak makes her cheer, not change
          // species, which is what the old excited asset did.
          Kiki(
            size: 90,
            mood: streakDays >= 3 ? KikiMood.celebrating : KikiMood.idle,
          ).animate().fadeIn(duration: 500.ms).scale(
                begin: const Offset(0.8, 0.8),
                duration: 500.ms,
                curve: Curves.elasticOut,
              ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 4,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: color.withOpacity(0.85),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
