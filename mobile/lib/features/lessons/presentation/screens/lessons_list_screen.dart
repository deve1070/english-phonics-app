import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../phonics/data/datasources/lessons_remote_datasource.dart';
import '../../../phonics/domain/entities/lesson_entity.dart';
import '../../../home/presentation/widgets/lesson_card.dart';
import '../../../home/presentation/widgets/level_style.dart';

// ── State ─────────────────────────────────────────────────────────
abstract class LessonsListState extends Equatable {
  const LessonsListState();
  @override
  List<Object?> get props => [];
}

class LessonsListInitial extends LessonsListState {
  const LessonsListInitial();
}

class LessonsListLoading extends LessonsListState {
  const LessonsListLoading();
}

class LessonsListLoaded extends LessonsListState {
  final List<LessonEntity> lessons;
  final String selectedLevel; // 'ALL' or 'LEVEL1'..'LEVEL5'

  const LessonsListLoaded({
    required this.lessons,
    this.selectedLevel = 'ALL',
  });

  List<LessonEntity> get filtered => selectedLevel == 'ALL'
      ? lessons
      : lessons.where((l) => l.level == selectedLevel).toList();

  LessonsListLoaded copyWith({String? selectedLevel}) => LessonsListLoaded(
        lessons: lessons,
        selectedLevel: selectedLevel ?? this.selectedLevel,
      );

  @override
  List<Object?> get props => [lessons, selectedLevel];
}

class LessonsListError extends LessonsListState {
  final String message;
  const LessonsListError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── Cubit ─────────────────────────────────────────────────────────
class LessonsListCubit extends Cubit<LessonsListState> {
  final LessonsRemoteDataSource _dataSource;

  LessonsListCubit(this._dataSource) : super(const LessonsListInitial());

  factory LessonsListCubit.create() =>
      LessonsListCubit(LessonsRemoteDataSource(getIt<Dio>()));

  Future<void> load() async {
    emit(const LessonsListLoading());
    try {
      final lessons = await _dataSource.getLessons();
      emit(LessonsListLoaded(lessons: lessons));
    } on DioException catch (e) {
      emit(LessonsListError(e.message ?? 'Failed to load lessons'));
    } catch (e) {
      emit(LessonsListError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  void filterByLevel(String level) {
    final state = this.state;
    if (state is LessonsListLoaded) {
      emit(state.copyWith(selectedLevel: level));
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────
class LessonsListScreen extends StatelessWidget {
  const LessonsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LessonsListCubit.create()..load(),
      child: const _LessonsListView(),
    );
  }
}

class _LessonsListView extends StatelessWidget {
  const _LessonsListView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocBuilder<LessonsListCubit, LessonsListState>(
        builder: (context, state) {
          if (state is LessonsListLoading || state is LessonsListInitial) {
            return const _LoadingSkeleton();
          }
          if (state is LessonsListError) {
            return _ErrorView(
              message: state.message,
              onRetry: () => context.read<LessonsListCubit>().load(),
            );
          }
          if (state is LessonsListLoaded) {
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
  final LessonsListLoaded state;
  const _LoadedView({required this.state});

  static const _levels = [
    'ALL',
    'LEVEL1',
    'LEVEL2',
    'LEVEL3',
    'LEVEL4',
    'LEVEL5'
  ];

  String _tabLabel(String level) {
    if (level == 'ALL') return 'All';
    return LevelStyle.label(level);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = state.filtered;

    return CustomScrollView(
      slivers: [
        // ── App bar ───────────────────────────────────────────
        SliverAppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          pinned: true,
          leading: IconButton(
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_rounded,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
            onPressed: () => context.pop(),
          ),
          title: Column(
            children: [
              Text('All Lessons', style: AppTextStyles.headingSmall),
              Text(
                '${state.lessons.length} lessons total',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: _LevelFilterTabs(
              levels: _levels,
              selected: state.selectedLevel,
              tabLabel: _tabLabel,
              onSelected: (level) =>
                  context.read<LessonsListCubit>().filterByLevel(level),
            ),
          ),
        ),

        // ── Stats bar ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: _StatsRow(lessons: state.lessons),
          ),
        ),

        // ── Lessons grid ──────────────────────────────────────
        filtered.isEmpty
            ? SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    children: [
                      const Text('📭', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'No lessons in this level yet.',
                        style: AppTextStyles.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.82,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final lesson = filtered[index];
                      // Global index for lock logic
                      final globalIndex = state.lessons.indexOf(lesson);
                      return LessonCard(
                        lesson: lesson,
                        index: globalIndex,
                        onTap: () => context.push('/lessons/${lesson.id}'),
                      )
                          .animate(
                            delay: Duration(milliseconds: index * 60),
                          )
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.12, end: 0, duration: 300.ms);
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
      ],
    );
  }
}

// ── Level filter tabs ─────────────────────────────────────────────
class _LevelFilterTabs extends StatelessWidget {
  final List<String> levels;
  final String selected;
  final String Function(String) tabLabel;
  final ValueChanged<String> onSelected;

  const _LevelFilterTabs({
    required this.levels,
    required this.selected,
    required this.tabLabel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: levels.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final level = levels[i];
          final isSelected = level == selected;
          final color =
              level == 'ALL' ? AppColors.coral : LevelStyle.color(level);

          return GestureDetector(
            onTap: () => onSelected(level),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs + 2,
              ),
              decoration: BoxDecoration(
                color: isSelected ? color : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                  color: isSelected ? color : color.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (level != 'ALL') ...[
                    Text(
                      LevelStyle.emoji(level),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    tabLabel(level),
                    style: AppTextStyles.label.copyWith(
                      color: isSelected ? Colors.white : color,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final List<LessonEntity> lessons;
  const _StatsRow({required this.lessons});

  @override
  Widget build(BuildContext context) {
    final completed = lessons.where((l) => l.isCompleted).length;
    final inProgress =
        lessons.where((l) => l.isStarted && !l.isCompleted).length;
    final notStarted = lessons.length - completed - inProgress;

    return Row(
      children: [
        _StatChip(
          label: 'Done',
          value: '$completed',
          color: AppColors.green,
          icon: '✅',
        ),
        const SizedBox(width: AppSpacing.sm),
        _StatChip(
          label: 'In progress',
          value: '$inProgress',
          color: AppColors.teal,
          icon: '🔄',
        ),
        const SizedBox(width: AppSpacing.sm),
        _StatChip(
          label: 'Not started',
          value: '$notStarted',
          color: AppColors.textSecondary,
          icon: '🔒',
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTextStyles.headingSmall.copyWith(
                color: color,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: const BackButton(),
          title: Text('All Lessons', style: AppTextStyles.headingSmall),
          centerTitle: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.82,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, index) => _SkeletonCard(
                delay: Duration(milliseconds: index * 60),
              ),
              childCount: 8,
            ),
          ),
        ),
      ],
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  final Duration delay;
  const _SkeletonCard({required this.delay});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.85).animate(
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
      animation: _anim,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          color: AppColors.border.withOpacity(_anim.value),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    ).animate(delay: widget.delay).fadeIn(duration: 300.ms);
  }
}

// ── Error view ────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('😅', style: TextStyle(fontSize: 64)),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Could not load lessons',
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
