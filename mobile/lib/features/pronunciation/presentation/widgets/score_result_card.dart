import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/mascot/kiki.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/pressable.dart';
import '../../domain/word_alignment.dart';
import '../cubit/pronunciation_state.dart';
import 'star_rating.dart';

/// Shown after an attempt.
///
/// Three deliberate departures from what this replaced:
///
/// * No numeric score. Children see stars; the number is for parents.
/// * Kiki's reaction tracks effort, not accuracy — she is never
///   disappointed, because a dejected mascot teaches a child that reading
///   makes someone unhappy.
/// * The word breakdown is the actual feedback. "Try again" is not
///   actionable; "this word was tricky" is.
class ScoreResultCard extends StatelessWidget {
  final PronunciationScored state;

  /// What the child was asked to read, needed to align against what was
  /// heard.
  final String expectedText;
  final VoidCallback onTryAgain;
  final VoidCallback onNext;

  const ScoreResultCard({
    super.key,
    required this.state,
    required this.expectedText,
    required this.onTryAgain,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final stars = starsForScore(state.score);
    final words = alignWords(expected: expectedText, heard: state.heardText);
    final trickyCount =
        words.where((w) => w.outcome == WordOutcome.missed).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: PaperCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        shadow: AppShadows.floating,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Kiki(
              size: 108,
              mood: state.isCompleted
                  ? KikiMood.celebrating
                  : KikiMood.encouraging,
            ),
            const SizedBox(height: AppSpacing.sm),

            Text(
              state.grade,
              style: AppTextStyles.displaySmall,
              textAlign: TextAlign.center,
            ).animate(delay: 200.ms).fadeIn(duration: 300.ms),

            const SizedBox(height: AppSpacing.md),
            StarRating(stars: stars),
            const SizedBox(height: AppSpacing.md),

            if (state.isPersonalBest)
              const _Banner(
                icon: Icons.trending_up_rounded,
                text: 'Your best yet!',
                color: AppColors.leaf,
              ).animate(delay: 700.ms).fadeIn().slideY(begin: 0.4, end: 0),

            if (words.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _WordBreakdown(words: words),
              const SizedBox(height: AppSpacing.sm),
              Text(
                trickyCount == 0
                    ? 'You said every word!'
                    : trickyCount == 1
                        ? 'One word to practise'
                        : '$trickyCount words to practise',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            Row(
              children: [
                Expanded(
                  child: Pressable(
                    onTap: onTryAgain,
                    color: AppColors.surface,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    semanticLabel: 'Try again',
                    child: const _ButtonLabel(
                      icon: Icons.refresh_rounded,
                      // Never "retry" as a consolation: the server keeps the
                      // best score, so another go is a free shot at a better
                      // one and should sound like one.
                      text: 'One more go',
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Pressable(
                    onTap: onNext,
                    color: AppColors.leaf,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    semanticLabel: 'Next exercise',
                    child: const _ButtonLabel(
                      icon: Icons.arrow_forward_rounded,
                      text: 'Next',
                      color: AppColors.onInk,
                    ),
                  ),
                ),
              ],
            ).animate(delay: 800.ms).fadeIn(duration: 300.ms),
          ],
        ),
      ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _ButtonLabel({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.buttonMedium.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// The sentence, re-rendered with each word marked.
///
/// Words the child said are green with a solid rule; the ones that slipped
/// are amber with a dashed one. Colour is never the only signal — the rule
/// style carries the same information for a colour-blind child, and that is
/// roughly one boy in twelve.
class _WordBreakdown extends StatelessWidget {
  final List<WordResult> words;

  const _WordBreakdown({required this.words});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderSoft, width: 1.5),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (var i = 0; i < words.length; i++)
            _WordChip(result: words[i], index: i),
        ],
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  final WordResult result;
  final int index;

  const _WordChip({required this.result, required this.index});

  @override
  Widget build(BuildContext context) {
    final said = result.outcome == WordOutcome.said;
    final color = said ? AppColors.correct : AppColors.retry;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          result.word,
          style: AppTextStyles.headingSmall.copyWith(
            color: said ? AppColors.ink : AppColors.inkSoft,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 4,
          width: (result.word.length * 9.0).clamp(18.0, 140.0),
          child: CustomPaint(painter: _UnderlinePainter(color, dashed: !said)),
        ),
      ],
    )
        .animate(delay: Duration(milliseconds: 500 + 60 * index))
        .fadeIn(duration: 220.ms)
        .slideY(begin: 0.35, end: 0, duration: 220.ms);
  }
}

class _UnderlinePainter extends CustomPainter {
  final Color color;
  final bool dashed;

  _UnderlinePainter(this.color, {required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;

    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    const dash = 5.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dash).clamp(0, size.width), y),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_UnderlinePainter old) =>
      old.color != color || old.dashed != dashed;
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Banner({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.leafLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Text(
            text,
            style: AppTextStyles.headingSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
