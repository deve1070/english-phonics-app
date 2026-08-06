import 'package:flutter/material.dart';
import '../../../../core/mascot/kiki.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';
import '../widgets/home_greeting_header.dart';
import '../widgets/lesson_card.dart';
import '../../../engagement/presentation/widgets/streak_badge.dart';
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

              // Four cards used to sit here: today's quest, the week's
              // goal, Find the Sound and Spelling Bee. Each was a choice,
              // and choosing between four activities is a harder task than
              // any one of them. For a child who came to learn a letter it
              // is a planning problem set before the lesson starts, and
              // planning is the part of this they are least able to do.
              //
              // None of them is gone as a feature. They belong in the
              // sequence the app plays — handed over one at a time, when
              // they fit — rather than laid out as a menu for a
              // five-year-old to build their own lesson from.
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
