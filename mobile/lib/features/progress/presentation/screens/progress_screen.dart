import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../home/presentation/widgets/level_style.dart';
import '../../../phonics/domain/entities/lesson_entity.dart';
import '../cubit/progress_cubit.dart';
import '../cubit/progress_state.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProgressCubit.create()..load(),
      child: const _ProgressView(),
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocBuilder<ProgressCubit, ProgressState>(
        builder: (context, state) {
          if (state is ProgressLoading || state is ProgressInitial) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.teal),
              ),
            );
          }
          if (state is ProgressError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('😅', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: AppSpacing.md),
                    Text(state.message,
                        style: AppTextStyles.bodyMedium,
                        textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton(
                      onPressed: () => context.read<ProgressCubit>().load(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state is ProgressLoaded) {
            return _LoadedView(state: state);
          }
          return const SizedBox();
        },
      ),
    );
  }
}

// ── Loaded view ───────────────────────────────────────────────────
class _LoadedView extends StatelessWidget {
  final ProgressLoaded state;
  const _LoadedView({required this.state});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── App bar ───────────────────────────────────────────
        SliverAppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          floating: true,
          title: Text('My Progress', style: AppTextStyles.headingMedium),
          centerTitle: false,
          actions: [
            // Refresh button
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: AppColors.textSecondary),
              onPressed: () => context.read<ProgressCubit>().load(),
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Stats row ────────────────────────────────
                _StatsRow(state: state).animate().fadeIn(duration: 400.ms),

                const SizedBox(height: AppSpacing.xl),

                // ── Overall progress bar ──────────────────────
                _OverallProgressBar(state: state)
                    .animate(delay: 100.ms)
                    .fadeIn(duration: 400.ms),

                const SizedBox(height: AppSpacing.xl),

                // ── Streak card — only show when streak > 0 ───
                if (state.streakDays > 0) ...[
                  _StreakCard(streakDays: state.streakDays)
                      .animate(delay: 150.ms)
                      .fadeIn(duration: 400.ms),
                  const SizedBox(height: AppSpacing.xl),
                ],

                // ── Feedback card (NEW) ───────────────────────
                _FeedbackCard(state: state)
                    .animate(delay: 200.ms)
                    .fadeIn(duration: 400.ms),

                const SizedBox(height: AppSpacing.xl),

                // ── Lesson breakdown header ───────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Lesson Breakdown', style: AppTextStyles.headingSmall),
                    TextButton(
                      onPressed: () => context.push('/lessons'),
                      child: Text(
                        'See all',
                        style: AppTextStyles.buttonMedium
                            .copyWith(color: AppColors.teal),
                      ),
                    ),
                  ],
                ).animate(delay: 250.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),

        // ── Lesson rows ───────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _LessonProgressRow(
                lesson: state.lessons[index],
                index: index,
              )
                  .animate(
                    delay: Duration(milliseconds: 300 + index * 60),
                  )
                  .fadeIn(duration: 350.ms)
                  .slideX(begin: 0.1, end: 0, duration: 350.ms),
              childCount: state.lessons.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Feedback card (NEW) ────────────────────────────────────────────
class _FeedbackCard extends StatelessWidget {
  final ProgressLoaded state;
  const _FeedbackCard({required this.state});

  Color get _scoreColor {
    final score = state.averageRecentScore;
    if (score == null) return AppColors.teal;
    if (score >= 90) return AppColors.green;
    if (score >= 70) return AppColors.teal;
    return AppColors.coral;
  }

  String get _emoji {
    final score = state.averageRecentScore;
    if (score == null) return '🎯';
    if (score >= 90) return '🌟';
    if (score >= 70) return '😊';
    return '💪';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: _scoreColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: _scoreColor.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _scoreColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(_emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coach says',
                  style: AppTextStyles.label.copyWith(color: _scoreColor),
                ),
                const SizedBox(height: 4),
                Text(
                  state.feedbackMessage,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final ProgressLoaded state;
  const _StatsRow({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          emoji: '📚',
          value: '${state.completedLessons}',
          label: 'Lessons Done',
          color: AppColors.teal,
        ),
        const SizedBox(width: AppSpacing.md),
        _StatCard(
          emoji: '✏️',
          value: '${state.completedExercises}',
          label: 'Exercises',
          color: AppColors.coral,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(value,
                style: AppTextStyles.headingLarge.copyWith(color: color)),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Overall progress bar ──────────────────────────────────────────
class _OverallProgressBar extends StatelessWidget {
  final ProgressLoaded state;
  const _OverallProgressBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final pct = state.overallProgress;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Overall Completion', style: AppTextStyles.headingSmall),
              Text(
                '${(pct * 100).toInt()}%',
                style:
                    AppTextStyles.headingSmall.copyWith(color: AppColors.coral),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.coral.withOpacity(0.12),
              valueColor: const AlwaysStoppedAnimation(AppColors.coral),
              minHeight: 14,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${state.completedExercises} of ${state.totalExercises} exercises completed',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ── Streak card ───────────────────────────────────────────────────
class _StreakCard extends StatelessWidget {
  final int streakDays;
  const _StreakCard({required this.streakDays});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.coral.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 40)),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$streakDays Day Streak!',
                  style:
                      AppTextStyles.headingMedium.copyWith(color: Colors.white),
                ),
                Text(
                  "You're on fire! Keep it up!",
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: Colors.white.withOpacity(0.85)),
                ),
              ],
            ),
          ),
          Column(
            children: List.generate(
              min(streakDays, 7),
              (i) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lesson progress row ───────────────────────────────────────────
class _LessonProgressRow extends StatelessWidget {
  final LessonEntity lesson;
  final int index;
  const _LessonProgressRow({required this.lesson, required this.index});

  String _getPhonemesDisplay() {
    return lesson.phonemes.map((p) {
      String spelling = p.symbol;
      if (spelling.contains('(')) {
        final match = RegExp(r'\(([^)]+)\)').firstMatch(spelling);
        if (match != null) {
          spelling = match.group(1)!.trim();
        }
      }
      
      spelling = spelling.replaceAll('-', '').trim();
      if (spelling.isEmpty) return '';
      
      if (spelling.length == 1) {
        return '${spelling.toUpperCase()}${spelling.toLowerCase()}';
      }
      return '${spelling[0].toUpperCase()}${spelling.substring(1).toLowerCase()}';
    }).where((s) => s.isNotEmpty).join('  ');
  }

  @override
  Widget build(BuildContext context) {
    final color = LevelStyle.color(lesson.level);
    final progress = lesson.progressPercent;
    final phonemesDisplay = _getPhonemesDisplay();

    return GestureDetector(
      onTap: () => context.push('/lessons/${lesson.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: lesson.isCompleted
                ? AppColors.green.withOpacity(0.4)
                : AppColors.border,
            width: 1.5,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Center(
                child: Text(
                  LevelStyle.emoji(lesson.level),
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          phonemesDisplay,
                          style: AppTextStyles.headingSmall.copyWith(
                            fontSize: 20,
                            color: color,
                            fontFamily: 'PatrickHand',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${lesson.completedExercises}/${lesson.totalExercises}',
                        style: AppTextStyles.label.copyWith(color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: color.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation(
                        lesson.isCompleted ? AppColors.green : color,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lesson.isCompleted
                        ? '✅ Completed'
                        : lesson.isStarted
                            ? '${LevelStyle.label(lesson.level)} · ${(progress * 100).toInt()}% done'
                            : '${LevelStyle.label(lesson.level)} · Tap to start',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 11,
                      color: lesson.isCompleted
                          ? AppColors.green
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Icon(
              lesson.isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.arrow_forward_ios_rounded,
              color: lesson.isCompleted ? AppColors.green : AppColors.border,
              size: lesson.isCompleted ? 24 : 16,
            ),
          ],
        ),
      ),
    );
  }
}
