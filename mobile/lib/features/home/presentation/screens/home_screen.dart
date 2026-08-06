import 'package:flutter/material.dart';
import '../../../../core/mascot/kiki.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/pressable.dart';
import '../../../../core/router/app_routes.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';
import '../widgets/home_greeting_header.dart';
import '../widgets/lesson_card.dart';
import '../../../engagement/data/engagement_models.dart';
import '../../../engagement/presentation/widgets/quest_card.dart';
import '../../../engagement/presentation/widgets/streak_badge.dart';
import '../../../engagement/presentation/widgets/week_medal.dart';
import '../../../phonics/domain/entities/lesson_entity.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit.create()..load(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          if (state is HomeLoading || state is HomeInitial) {
            return const _LoadingSkeleton();
          }
          if (state is HomeError) {
            return _ErrorView(
              message: state.message,
              onRetry: () => context.read<HomeCubit>().load(),
            );
          }
          if (state is HomeLoaded) {
            return _LoadedView(state: state);
          }
          return const SizedBox();
        },
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  final HomeLoaded state;
  const _LoadedView({required this.state});

  @override
  Widget build(BuildContext context) {
    final lessons = state.lessons;
    int activeIndex = lessons.indexWhere((l) => !l.isCompleted);
    if (activeIndex == -1) {
      activeIndex = lessons.isNotEmpty ? lessons.length - 1 : 0;
    }

    final filteredLessons = lessons.isNotEmpty
        ? [
            lessons[activeIndex],
            ...lessons.sublist(
              (activeIndex + 1).clamp(0, lessons.length),
              (activeIndex + 4).clamp(0, lessons.length),
            ),
          ]
        : <LessonEntity>[];

    return CustomScrollView(
      slivers: [
        // ── Transparent SliverAppBar (Clean & Blank) ────────────
        SliverAppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          floating: true,
          expandedHeight: 0,
        ),

        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              HomeGreetingHeader(
                name: state.user.name,
                streakDays: state.streakDays,
              ),

              // The streak sits under the greeting rather than inside it,
              // because below three days it renders nothing and the
              // header must not be left with a hole in it.
              if (state.streak.isWorthShowing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: StreakBadge(streak: state.streak),
                  ),
                ),

              const SizedBox(height: AppSpacing.lg),

              // Today's three things, above the lesson path: it is the
              // one thing on this screen that can be finished.
              if (!state.quest.isEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: QuestCard(
                    quest: state.quest,
                    onTapItem: (item) => context.push(
                      '${AppRoutes.practice}/${item.exerciseId}',
                      extra: {'content': item.content, 'type': item.type},
                    ),
                  ),
                ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0),

              const SizedBox(height: AppSpacing.lg),

              // The week's promise, with the prize already on screen. It
              // sits under the quest — today's work comes first — but
              // above everything else, because a goal a child has to go
              // looking for is not one they are working towards.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _WeekCard(
                  goal: state.goal,
                  onTap: () => context.push(AppRoutes.goal),
                ),
              ).animate(delay: 80.ms).fadeIn(duration: 350.ms),

              const SizedBox(height: AppSpacing.md),

              // The listening game, above the shelves and always present.
              // Unlike everything else on this screen it needs no
              // microphone, no upload and no Azure, so it is the one thing
              // here that still works when the connection does not — and
              // the one rung a child who cannot yet say a sound can
              // always succeed on.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _ListenGameCard(
                  onTap: () => context.push(AppRoutes.recognition),
                ),
              ).animate(delay: 100.ms).fadeIn(duration: 350.ms),

              const SizedBox(height: AppSpacing.md),

              // The spelling game, which used to be a tab of its own. It is
              // a thing to do, so it belongs among the things to do rather
              // than in the furniture of the app.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _SpellingGameCard(
                  onTap: () => context.push(AppRoutes.spellingBee),
                ),
              ).animate(delay: 120.ms).fadeIn(duration: 350.ms),

              // "My Sounds" and "My Stories" used to sit here. They are
              // rewards rather than tasks, and they have moved to Me, next
              // to the child's own name and the rest of what they have
              // earned — which leaves this screen holding only things to
              // do.
              const SizedBox(height: AppSpacing.lg),

              // Lessons header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'My Phonics Path 🚀',
                  style: AppTextStyles.headingMedium.copyWith(fontSize: 22),
                ).animate(delay: 150.ms).fadeIn(duration: 350.ms),
              ),

              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),

        // ── Lessons single-column path ───────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final lesson = filteredLessons[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: SizedBox(
                    height: 190,
                    child: LessonCard(
                      lesson: lesson,
                      index: index,
                      onTap: () => context.push('/lessons/${lesson.id}'),
                    ),
                  ),
                )
                    .animate(delay: Duration(milliseconds: 200 + index * 60))
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.1, end: 0, duration: 350.ms);
              },
              childCount: filteredLessons.length,
            ),
          ),
        ),
      ],
    );
  }
}

/// This week's promise, on the first screen.
///
/// Three states, and none of them is a scolding. Before the child has
/// chosen it is an open question; after, it is the prize with however much
/// of the week is done showing through it; once kept, it is the prize in
/// full colour and a sentence in the past tense. A week going badly is
/// simply a medal that has not filled up much — there is no red, no "you
/// are behind", and nothing counting the days left.
class _WeekCard extends StatelessWidget {
  final WeeklyGoal goal;
  final VoidCallback onTap;

  const _WeekCard({required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final kind = goal.kind;

    final title = switch ((kind, goal.isComplete)) {
      (null, _) => 'What will you do this week?',
      (_, true) => 'You did it!',
      _ => kind!.label(goal.target),
    };
    final line = switch ((kind, goal.isComplete)) {
      (null, _) => 'Pick one thing. Tap to choose.',
      (_, true) => 'You said you would, and you did.',
      _ => '${goal.done} of ${goal.target} ${kind!.noun}',
    };

    return Pressable(
      onTap: onTap,
      color: goal.isComplete ? AppColors.honeyLight : AppColors.surface,
      borderColor: AppColors.border,
      padding: const EdgeInsets.all(AppSpacing.md),
      semanticLabel: '$title. $line',
      child: Row(
        children: [
          // The medal fills from the bottom as the week goes, exactly as
          // it does on the goal screen — the same object in both places,
          // so the one on the home screen is recognisably the one the
          // child is working towards.
          FillingMedal(
            weekStart: goal.weekStart,
            kind: kind,
            fraction: goal.fraction,
            size: 56,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.headingSmall),
                const SizedBox(height: 2),
                Text(
                  line,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 26, color: AppColors.inkFaint),
        ],
      ),
    );
  }
}

/// The way into the listening game.
///
/// Phrased as an invitation with no number attached to it. There is no
/// score on this card and none on the game's own summary either, because
/// the point of this exercise is that it is the one a child can walk into
/// and come out of having got something right.
class _ListenGameCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ListenGameCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      color: AppColors.leafLight,
      borderColor: AppColors.border,
      padding: const EdgeInsets.all(AppSpacing.md),
      semanticLabel: 'Find the sound — a listening game',
      child: Row(
        children: [
          const Icon(Icons.hearing_rounded, size: 30, color: AppColors.leaf),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Find the sound', style: AppTextStyles.headingSmall),
                const SizedBox(height: 2),
                Text(
                  'Listen, then point at it.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 26, color: AppColors.inkFaint),
        ],
      ),
    );
  }
}

class _SpellingGameCard extends StatelessWidget {
  final VoidCallback onTap;
  const _SpellingGameCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      color: AppColors.skyLight,
      borderColor: AppColors.border,
      padding: const EdgeInsets.all(AppSpacing.md),
      semanticLabel: 'Spelling Bee — hear a word and spell it',
      child: Row(
        children: [
          const Icon(Icons.spellcheck_rounded, size: 30, color: AppColors.sky),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Spelling Bee', style: AppTextStyles.headingSmall),
                const SizedBox(height: 2),
                Text(
                  'Hear a word, then build it.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 26, color: AppColors.inkFaint),
        ],
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xl),
          // Greeting skeleton
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Shimmer(width: 100, height: 16),
                    const SizedBox(height: 8),
                    _Shimmer(width: 160, height: 32),
                    const SizedBox(height: 8),
                    _Shimmer(width: 200, height: 28),
                  ],
                ),
              ),
              _Shimmer(width: 90, height: 90, isCircle: true),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _Shimmer(width: double.infinity, height: 110),
          const SizedBox(height: AppSpacing.xl),
          _Shimmer(width: double.infinity, height: 110),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(child: _Shimmer(width: double.infinity, height: 160)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _Shimmer(width: double.infinity, height: 160)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Shimmer extends StatefulWidget {
  final double width;
  final double height;
  final bool isCircle;

  const _Shimmer({
    required this.width,
    required this.height,
    this.isCircle = false,
  });

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.border.withOpacity(_animation.value),
          shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius:
              widget.isCircle ? null : BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Encouraging rather than dismayed: the app broke, not the
            // child, and she is the last thing they should read as upset.
            const Kiki(size: 120, mood: KikiMood.encouraging),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Oops! Something went wrong',
              style: AppTextStyles.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
