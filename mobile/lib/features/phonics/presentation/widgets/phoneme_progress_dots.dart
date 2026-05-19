import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';

class PhonemeProgressDots extends StatelessWidget {
  final int total;
  final int current;
  final Color color;

  const PhonemeProgressDots({
    super.key,
    required this.total,
    required this.current,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Show at most 8 dots — condense if more
    final displayCount = total.clamp(1, 8);
    final scale = total > 8 ? 8 / total : 1.0;
    final displayCurrent = (current * scale).round().clamp(0, displayCount - 1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(displayCount, (i) {
        final isActive = i == displayCurrent;
        final isPast = i < displayCurrent;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isPast
                ? AppColors.green
                : isActive
                    ? color
                    : color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        );
      }),
    );
  }
}
