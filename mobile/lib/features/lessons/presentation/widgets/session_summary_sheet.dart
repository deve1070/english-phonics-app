import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/mascot/kiki.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/pressable.dart';
import '../../../../core/theme/tibeb_band.dart';
import '../../../pronunciation/presentation/widgets/star_rating.dart';

/// What a child did in one sitting.
class SessionTally {
  final int exercisesAttempted;
  final int starsEarned;

  /// Sounds worked on, in the order they were met.
  final List<String> soundsPractised;

  /// Practice streak *after* this session, and whether it grew today.
  final int streakDays;
  final bool streakAdvanced;

  const SessionTally({
    required this.exercisesAttempted,
    required this.starsEarned,
    this.soundsPractised = const [],
    this.streakDays = 0,
    this.streakAdvanced = false,
  });

  bool get isEmpty => exercisesAttempted == 0;
}

/// The end of a session, given a shape.
///
/// Sessions used to simply stop — the child closed the app mid-scroll and
/// nothing marked that anything had happened. People remember the peak and
/// the end of an experience far more than the middle, so an ending is
/// disproportionately worth building.
///
/// It also does specific work for this product. Parents cap daily minutes,
/// which means the app will regularly be interrupted; having a real closing
/// beat means hitting that cap can be dressed as *finishing* rather than
/// being cut off. And it is where the streak is shown, which is the one
/// mechanic that rewards coming back tomorrow instead of staying longer
/// today.
class SessionSummarySheet extends StatelessWidget {
  final SessionTally tally;
  final VoidCallback onDone;

  /// Set when the parent's daily limit ended the session, so the copy can
  /// frame the stop as a natural finish.
  final bool reachedDailyLimit;

  const SessionSummarySheet({
    super.key,
    required this.tally,
    required this.onDone,
    this.reachedDailyLimit = false,
  });

  static Future<void> show(
    BuildContext context, {
    required SessionTally tally,
    bool reachedDailyLimit = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Not dismissible by dragging away: the ending is the point, and it
      // is three taps long at most.
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => SessionSummarySheet(
        tally: tally,
        reachedDailyLimit: reachedDailyLimit,
        onDone: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        border: Border(
          top: BorderSide(color: AppColors.border, width: AppBorders.heavy),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TibebBand(height: 10),
              const SizedBox(height: AppSpacing.lg),

              const Kiki(size: 96, mood: KikiMood.celebrating),
              const SizedBox(height: AppSpacing.sm),

              Text(
                reachedDailyLimit
                    // Never "time's up". The limit is the parent's, not a
                    // punishment, and a child should leave feeling they
                    // completed something.
                    ? "That's today's reading done!"
                    : 'Great practice!',
                style: AppTextStyles.displaySmall,
                textAlign: TextAlign.center,
              ).animate(delay: 150.ms).fadeIn(duration: 300.ms),

              const SizedBox(height: AppSpacing.lg),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Tally(
                    value: '${tally.exercisesAttempted}',
                    label: tally.exercisesAttempted == 1 ? 'try' : 'tries',
                  ),
                  _Tally(
                    value: '${tally.starsEarned}',
                    label: tally.starsEarned == 1 ? 'star' : 'stars',
                    icon: Icons.star_rounded,
                    color: AppColors.honey,
                  ),
                  if (tally.streakDays > 0)
                    _Tally(
                      value: '${tally.streakDays}',
                      label: tally.streakDays == 1 ? 'day' : 'days',
                      icon: Icons.local_fire_department_rounded,
                      color: AppColors.crest,
                      highlight: tally.streakAdvanced,
                    ),
                ],
              ).animate(delay: 350.ms).fadeIn().slideY(begin: 0.25, end: 0),

              if (tally.soundsPractised.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                const Text('Sounds you practised', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final sound in tally.soundsPractised)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs + 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.leafLight,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: AppColors.leaf,
                            width: AppBorders.hairline,
                          ),
                        ),
                        child: Text(
                          sound,
                          style: AppTextStyles.headingSmall
                              .copyWith(color: AppColors.leafDark),
                        ),
                      ),
                  ],
                ).animate(delay: 550.ms).fadeIn(),
              ],

              if (tally.streakAdvanced) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  tally.streakDays == 1
                      ? 'Come back tomorrow to start a streak!'
                      : "${tally.streakDays} days in a row — see you tomorrow!",
                  style: AppTextStyles.mascotSpeech,
                  textAlign: TextAlign.center,
                ).animate(delay: 700.ms).fadeIn(),
              ],

              const SizedBox(height: AppSpacing.xl),

              SizedBox(
                width: double.infinity,
                child: Pressable(
                  onTap: onDone,
                  color: AppColors.leaf,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  semanticLabel: 'Finish',
                  child: Text(
                    'Done',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.buttonLarge
                        .copyWith(color: AppColors.onInk),
                  ),
                ),
              ).animate(delay: 850.ms).fadeIn(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final Color? color;
  final bool highlight;

  const _Tally({
    required this.value,
    required this.label,
    this.icon,
    this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.leaf;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 26, color: tint),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: AppTextStyles.headingLarge
                  .copyWith(fontSize: 30, color: tint),
            ),
          ],
        ),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );

    if (!highlight) return content;
    return content
        .animate(delay: 500.ms)
        .shimmer(duration: 900.ms, color: tint.withValues(alpha: 0.5))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.12, 1.12),
          duration: 300.ms,
          curve: Curves.easeOut,
        )
        .then()
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(0.893, 0.893),
          duration: 250.ms,
        );
  }
}

/// Accumulates a session as it happens, so the summary has something to
/// report. Deliberately in-memory and per-sitting: this is a closing beat,
/// not a second source of truth for progress. The server already holds the
/// durable record.
class SessionTracker {
  int _attempts = 0;
  int _stars = 0;
  final List<String> _sounds = [];

  void recordAttempt({required double score, String? sound}) {
    _attempts++;
    _stars += starsForScore(score);
    if (sound != null && sound.trim().isNotEmpty && !_sounds.contains(sound)) {
      _sounds.add(sound.trim());
    }
  }

  SessionTally build({int streakDays = 0, bool streakAdvanced = false}) =>
      SessionTally(
        exercisesAttempted: _attempts,
        starsEarned: _stars,
        soundsPractised: List.unmodifiable(_sounds),
        streakDays: streakDays,
        streakAdvanced: streakAdvanced,
      );

  void reset() {
    _attempts = 0;
    _stars = 0;
    _sounds.clear();
  }
}
