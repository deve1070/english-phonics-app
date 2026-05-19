import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';

class LetterTile extends StatelessWidget {
  final String letter;
  final bool isPlaced;
  final bool isCorrect; // shown on result
  final bool isWrong; // shown on result
  final VoidCallback? onTap;
  final int animationIndex;

  const LetterTile({
    super.key,
    required this.letter,
    this.isPlaced = false,
    this.isCorrect = false,
    this.isWrong = false,
    this.onTap,
    this.animationIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;
    Color textColor;

    if (isCorrect) {
      bgColor = AppColors.green.withOpacity(0.15);
      borderColor = AppColors.green;
      textColor = AppColors.green;
    } else if (isWrong) {
      bgColor = AppColors.coral.withOpacity(0.15);
      borderColor = AppColors.coral;
      textColor = AppColors.coral;
    } else if (isPlaced) {
      bgColor = AppColors.purple.withOpacity(0.1);
      borderColor = AppColors.purple.withOpacity(0.4);
      textColor = AppColors.textSecondary;
    } else {
      bgColor = AppColors.surface;
      borderColor = AppColors.teal;
      textColor = AppColors.textPrimary;
    }

    return GestureDetector(
      onTap: isPlaced
          ? null
          : () {
              HapticFeedback.lightImpact();
              onTap?.call();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: AppSizes.spellingTileSize,
        height: AppSizes.spellingTileSize,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: isPlaced
              ? null
              : [
                  BoxShadow(
                    color: AppColors.teal.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Center(
          child: Text(
            letter.toUpperCase(),
            style: AppTextStyles.spellingTile.copyWith(
              color: textColor,
              fontSize: isPlaced ? 22 : 26,
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: animationIndex * 60))
        .scale(
          begin: const Offset(0.6, 0.6),
          duration: 350.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 200.ms);
  }
}

// ── Answer slot — where placed letters go ─────────────────────────
class AnswerSlot extends StatelessWidget {
  final String? letter;
  final bool isCorrect;
  final bool isWrong;
  final VoidCallback? onTap; // tap to remove
  final int index;

  const AnswerSlot({
    super.key,
    required this.index,
    this.letter,
    this.isCorrect = false,
    this.isWrong = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = letter == null;

    Color borderColor;
    Color bgColor;

    if (isCorrect) {
      bgColor = AppColors.green.withOpacity(0.12);
      borderColor = AppColors.green;
    } else if (isWrong) {
      bgColor = AppColors.coral.withOpacity(0.12);
      borderColor = AppColors.coral;
    } else if (!isEmpty) {
      bgColor = AppColors.purple.withOpacity(0.08);
      borderColor = AppColors.purple;
    } else {
      bgColor = AppColors.surfaceVariant;
      borderColor = AppColors.border;
    }

    return GestureDetector(
      onTap: isEmpty
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap?.call();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: AppSizes.spellingTileSize,
        height: AppSizes.spellingTileSize,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: borderColor,
            width: isEmpty ? 1.5 : 2,
            style: isEmpty ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: isEmpty
            ? Center(
                child: Container(
                  width: 20,
                  height: 2,
                  color: borderColor.withOpacity(0.4),
                ),
              )
            : Center(
                child: Text(
                  letter!.toUpperCase(),
                  style: AppTextStyles.spellingTile.copyWith(
                    color: isCorrect
                        ? AppColors.green
                        : isWrong
                            ? AppColors.coral
                            : AppColors.purple,
                    fontSize: 26,
                  ),
                ),
              ).animate(key: ValueKey(letter)).scale(
                  begin: const Offset(0.5, 0.5),
                  duration: 250.ms,
                  curve: Curves.elasticOut,
                ),
      ),
    );
  }
}
