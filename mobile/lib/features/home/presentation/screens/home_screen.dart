import 'package:flutter/material.dart';
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
import '../../../engagement/presentation/widgets/quest_card.dart';
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

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _ShelfLinks(),
              ),

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

/// Two doors: the collection and the story shelf.
///
/// Both are rewards rather than tasks, so they sit between the quest and
/// the lesson path — reachable in one tap from the first screen, but not
/// competing with the thing the child is actually meant to do today.
class _ShelfLinks extends StatelessWidget {
  const _ShelfLinks();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ShelfLink(
            icon: Icons.auto_awesome_rounded,
            label: 'My Sounds',
            colour: AppColors.honeyLight,
            border: AppColors.honey,
            onTap: () => context.push(AppRoutes.collection),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _ShelfLink(
            icon: Icons.menu_book_rounded,
            label: 'My Stories',
            colour: AppColors.skyLight,
            border: AppColors.sky,
            onTap: () => context.push(AppRoutes.stories),
          ),
        ),
      ],
    );
  }
}

class _ShelfLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color colour;
  final Color border;
  final VoidCallback onTap;

  const _ShelfLink({
    required this.icon,
    required this.label,
    required this.colour,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      color: colour,
      borderColor: AppColors.border,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      semanticLabel: label,
      child: Row(
        children: [
          Icon(icon, size: 22, color: border),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.label.copyWith(color: AppColors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────
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
            Image.asset(
              'assets/images/popi.png',
              height: 120,
              errorBuilder: (_, __, ___) =>
                  const Text('😅', style: TextStyle(fontSize: 72)),
            ),
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
