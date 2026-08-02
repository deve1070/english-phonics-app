import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/mascot/kiki.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/pressable.dart';
import '../../data/engagement_models.dart';
import '../../data/engagement_remote_datasource.dart';
import '../widgets/week_medal.dart';

/// What the child decided to do this week, and the prize for doing it.
///
/// The choosing is the feature. A target the app hands down is homework;
/// one the child picked on Monday is a promise they made, and keeping it
/// is what builds the belief this whole thing exists to build — I can
/// decide to do something and then find that I did it.
///
/// So: three options, all reachable, sized from this child's own recent
/// weeks. The prize on screen from the first day, greyed, filling as the
/// week goes. And nothing anywhere that says a week was missed — a week
/// that ends short just ends, and Monday brings a fresh choice.
class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  late final EngagementRemoteDataSource _source =
      EngagementRemoteDataSource(getIt<Dio>());

  WeeklyGoal? _goal;
  String? _error;
  bool _choosing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final goal = await _source.getGoal();
    if (!mounted) return;
    setState(() => _goal = goal);
  }

  Future<void> _choose(GoalKind kind) async {
    setState(() => _choosing = true);
    try {
      final goal = await _source.chooseGoal(kind);
      if (!mounted) return;
      setState(() => _goal = goal);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message ?? 'Could not save your plan');
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = _goal;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        backgroundColor: AppColors.parchment,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 18, color: AppColors.ink),
          onPressed: () => context.pop(),
        ),
        title: Text('My Week', style: AppTextStyles.headingSmall),
        centerTitle: true,
      ),
      body: SafeArea(
        child: goal == null
            ? const Center(child: Kiki(size: 120, mood: KikiMood.thinking))
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.inkSoft),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (goal.isChosen)
                    _Promise(goal: goal)
                  else
                    _Chooser(
                      goal: goal,
                      busy: _choosing,
                      onChoose: _choose,
                    ),
                  if (goal.earnedWeeks.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _Shelf(weeks: goal.earnedWeeks),
                  ],
                ],
              ),
      ),
    );
  }
}

// ── Monday: three ways to spend the week ─────────────────────────────

class _Chooser extends StatelessWidget {
  final WeeklyGoal goal;
  final bool busy;
  final void Function(GoalKind) onChoose;

  const _Chooser({
    required this.goal,
    required this.busy,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        const Center(child: Kiki(size: 96, mood: KikiMood.idle)),
        const SizedBox(height: AppSpacing.md),
        Text(
          'What will you do this week?',
          style: AppTextStyles.headingMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          // Says out loud that all three are within reach. A child weighing
          // three options needs to know none of them is the trap.
          'Pick one. You can do any of them.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.inkSoft),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final option in goal.choices) ...[
          _ChoiceCard(
            option: option,
            weekStart: goal.weekStart,
            onTap: busy ? null : () => onChoose(option.kind),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final GoalOption option;
  final DateTime weekStart;
  final VoidCallback? onTap;

  const _ChoiceCard({
    required this.option,
    required this.weekStart,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      color: AppColors.surface,
      padding: const EdgeInsets.all(AppSpacing.md),
      semanticLabel: option.kind.label(option.target),
      child: Row(
        children: [
          // The same medal that will hang on the shelf, with this
          // option's mark on it. The child can see what each choice
          // leaves behind before they make it.
          WeekMedal(
            weekStart: weekStart,
            kind: option.kind,
            isEarned: false,
            size: 56,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              option.kind.label(option.target),
              style: AppTextStyles.bodyLarge,
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 26, color: AppColors.inkFaint),
        ],
      ),
    );
  }
}

// ── The rest of the week ─────────────────────────────────────────────

class _Promise extends StatelessWidget {
  final WeeklyGoal goal;
  const _Promise({required this.goal});

  @override
  Widget build(BuildContext context) {
    final kind = goal.kind!;

    return Column(
      children: [
        const SizedBox(height: AppSpacing.lg),
        _FillingMedal(goal: goal),
        const SizedBox(height: AppSpacing.lg),
        Text(
          goal.isComplete ? 'You did it!' : kind.label(goal.target),
          style: AppTextStyles.headingMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          goal.isComplete
              // Past tense, and about them: this is the sentence the whole
              // feature is for.
              ? 'You said you would, and you did.'
              : '${goal.done} of ${goal.target} ${kind.noun}',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.inkSoft),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!goal.isComplete) _Steps(goal: goal),
      ],
    );
  }
}

/// The prize for this week, at the size it deserves.
class _FillingMedal extends StatelessWidget {
  final WeeklyGoal goal;
  const _FillingMedal({required this.goal});

  @override
  Widget build(BuildContext context) {
    final medal = FillingMedal(
      weekStart: goal.weekStart,
      kind: goal.kind,
      fraction: goal.fraction,
      size: 160,
    );

    if (!goal.isComplete) return medal;
    return medal
        .animate()
        .scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1, 1),
          duration: 500.ms,
          curve: Curves.elasticOut,
        )
        .shimmer(delay: 400.ms, duration: 900.ms);
  }
}

/// The week as a row of steps, filled in as they are taken.
///
/// Countable objects rather than a percentage. A child can look at four
/// dots with two filled and know exactly what is left, which is not true
/// of "50%".
class _Steps extends StatelessWidget {
  final WeeklyGoal goal;
  const _Steps({required this.goal});

  @override
  Widget build(BuildContext context) {
    // Twelve is two rows of six, which is still countable at a glance.
    // Beyond that a row of dots becomes a texture rather than a number of
    // things, and the line underneath is doing the work anyway. The cut
    // has to sit above the commonest listening target or the goal a child
    // is most likely to pick is the one they can least see the shape of.
    if (goal.target > 12) return const SizedBox.shrink();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (var i = 0; i < goal.target; i++)
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < goal.done ? AppColors.leaf : AppColors.surface,
              border: Border.all(color: AppColors.ink, width: 2),
            ),
            child: i < goal.done
                ? const Icon(Icons.check_rounded,
                    size: 16, color: AppColors.onInk)
                : null,
          ),
      ],
    );
  }
}

// ── Weeks already kept ───────────────────────────────────────────────

class _Shelf extends StatelessWidget {
  final List<EarnedWeek> weeks;
  const _Shelf({required this.weeks});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          weeks.length == 1 ? 'A week you kept' : 'Weeks you kept',
          style: AppTextStyles.headingSmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            // Newest first: the most recent week is the one the child
            // wants to see, and the shelf grows to the right of it.
            for (final week in weeks.reversed)
              WeekMedal(
                weekStart: week.weekStart,
                kind: week.kind,
                isEarned: true,
                size: 64,
              ),
          ],
        ),
      ],
    );
  }
}
