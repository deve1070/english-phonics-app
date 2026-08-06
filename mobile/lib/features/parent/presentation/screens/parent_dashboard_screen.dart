import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/token_storage.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/screen_time/screen_time_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';

// ── Models ────────────────────────────────────────────────────────
class ChildSummaryModel {
  final int childId;
  final String childName;
  final String? nickname;
  final int lessonsCompleted;
  final int totalLessons;
  final double overallProgressPct;
  final double minutesToday;
  final int maxDailyMinutes;
  final bool isLimitReached;
  final int streakDays;

  /// This week's promise, as far as the parent needs to know it on the
  /// first screen they open.
  ///
  /// [keptTheWeek] is the one that has to be here rather than a tap away.
  /// A parent who promised the park on Saturday and is never told their
  /// child finished has been turned by this app into someone who breaks
  /// promises, which is worse than the feature not existing.
  final bool keptTheWeek;
  final String? promiseText;

  /// The child chose a goal and nobody has answered it. Stated once,
  /// never nagged.
  final bool promiseWanted;

  const ChildSummaryModel({
    required this.childId,
    required this.childName,
    this.nickname,
    required this.lessonsCompleted,
    required this.totalLessons,
    required this.overallProgressPct,
    required this.minutesToday,
    required this.maxDailyMinutes,
    required this.isLimitReached,
    required this.streakDays,
    this.keptTheWeek = false,
    this.promiseText,
    this.promiseWanted = false,
  });

  String get displayName => nickname ?? childName;

  factory ChildSummaryModel.fromJson(Map<String, dynamic> j) =>
      ChildSummaryModel(
        childId: j['child_id'] as int,
        childName: j['child_name'] as String,
        nickname: j['nickname'] as String?,
        lessonsCompleted: (j['lessons_completed'] as num).toInt(),
        totalLessons: (j['total_lessons'] as num).toInt(),
        overallProgressPct: (j['overall_progress_pct'] as num).toDouble(),
        minutesToday: (j['minutes_today'] as num).toDouble(),
        maxDailyMinutes: (j['max_daily_minutes'] as num).toInt(),
        isLimitReached: j['is_limit_reached'] as bool,
        streakDays: (j['streak_days'] as num).toInt(),
        keptTheWeek: j['kept_the_week'] as bool? ?? false,
        promiseText: j['promise_text'] as String?,
        promiseWanted: j['promise_wanted'] as bool? ?? false,
      );
}

class ParentDashboardData {
  final String parentName;
  final List<ChildSummaryModel> children;
  final String? subscriptionStatus;

  const ParentDashboardData({
    required this.parentName,
    required this.children,
    this.subscriptionStatus,
  });

  factory ParentDashboardData.fromJson(Map<String, dynamic> j) =>
      ParentDashboardData(
        parentName: j['parent_name'] as String,
        subscriptionStatus: j['subscription_status'] as String?,
        children: (j['children'] as List<dynamic>)
            .map((c) => ChildSummaryModel.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

// ── State ─────────────────────────────────────────────────────────
abstract class ParentDashboardState extends Equatable {
  const ParentDashboardState();
  @override
  List<Object?> get props => [];
}

class ParentDashboardInitial extends ParentDashboardState {
  const ParentDashboardInitial();
}

class ParentDashboardLoading extends ParentDashboardState {
  const ParentDashboardLoading();
}

class ParentDashboardLoaded extends ParentDashboardState {
  final ParentDashboardData data;
  const ParentDashboardLoaded(this.data);
  @override
  List<Object?> get props => [data];
}

class ParentDashboardError extends ParentDashboardState {
  final String message;
  const ParentDashboardError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── Cubit ─────────────────────────────────────────────────────────
class ParentDashboardCubit extends Cubit<ParentDashboardState> {
  final Dio _dio;
  final TokenStorage _tokenStorage;

  ParentDashboardCubit(this._dio, this._tokenStorage)
      : super(const ParentDashboardInitial());

  factory ParentDashboardCubit.create() => ParentDashboardCubit(
        getIt<Dio>(),
        getIt<TokenStorage>(),
      );

  Future<void> load() async {
    emit(const ParentDashboardLoading());
    try {
      final response = await _dio.get('/parents/dashboard');
      final data =
          ParentDashboardData.fromJson(response.data as Map<String, dynamic>);
      emit(ParentDashboardLoaded(data));
    } on DioException catch (e) {
      emit(ParentDashboardError(e.message ?? 'Failed to load dashboard'));
    } catch (e) {
      emit(ParentDashboardError(e.toString()));
    }
  }

  /// Switch into the child's learning session.
  /// Fetches a short-lived child token and stores it, then routes to home.
  Future<void> switchToChild(int childId) async {
    try {
      final parentJwt = await _tokenStorage.getAccessToken();
      if (parentJwt != null && parentJwt.isNotEmpty) {
        await _tokenStorage.saveParentAccessToken(parentJwt);
      }
      final response = await _dio.post('/parents/child-login/$childId');
      final token = response.data['access_token'] as String;
      await _tokenStorage.saveTokens(
        accessToken: token,
      );
      await _tokenStorage.saveUserRole('STUDENT');

      // Start counting screen time now that the child is actually in.
      // Must run after the parent JWT is stashed above: the interceptor
      // sends the parent token for /parents/* calls.
      await getIt<ScreenTimeService>().startSession(childId);
    } on DioException catch (e) {
      emit(ParentDashboardError(
        e.response?.data?['detail'] ?? 'Failed to switch to child session',
      ));
    } catch (e) {
      emit(ParentDashboardError('Failed to switch to child session: ${e.toString()}'));
    }
  }

  Future<void> logout() async {
    // Close any open session before the tokens go away — afterwards there is
    // no credential left to authorize the call.
    await getIt<ScreenTimeService>().endSession();
    await _tokenStorage.clearTokens();
  }

  Future<String?> generateLink() async {
    try {
      final response = await _dio.post('/auth/generate-child-link');
      return response.data['link'] as String;
    } catch (e) {
      return null;
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────
class ParentDashboardScreen extends StatelessWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ParentDashboardCubit.create()..load(),
      child: const _ParentDashboardView(),
    );
  }
}

class _ParentDashboardView extends StatelessWidget {
  const _ParentDashboardView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocBuilder<ParentDashboardCubit, ParentDashboardState>(
        builder: (context, state) {
          if (state is ParentDashboardLoading ||
              state is ParentDashboardInitial) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.coral),
              ),
            );
          }
          if (state is ParentDashboardError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('😅', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: AppSpacing.md),
                  Text(state.message, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<ParentDashboardCubit>().load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (state is ParentDashboardLoaded) {
            return _LoadedView(data: state.data);
          }
          return const SizedBox();
        },
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  final ParentDashboardData data;
  const _LoadedView({required this.data});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Header ────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _ParentHeader(
            parentName: data.parentName,
            onAdd: () => context.push(AppRoutes.addChild),
            onSettings: () => context.push(AppRoutes.parentSettings),
            onLogout: () async {
              await context.read<ParentDashboardCubit>().logout();
              if (context.mounted) context.go(AppRoutes.phoneLogin);
            },
            onGenerateLink: () async {
              final link = await context.read<ParentDashboardCubit>().generateLink();
              if (link != null && context.mounted) {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Invite Link'),
                    content: SelectableText(link),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      )
                    ],
                  )
                );
              }
            },
          ),
        ),

        // ── Children cards ─────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: data.children.isEmpty
              ? SliverToBoxAdapter(
                  child: _EmptyChildren(
                    onAdd: () => context.push(AppRoutes.addChild),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _ChildCard(
                      child: data.children[i],
                      onViewProgress: () => context.push(
                        '${AppRoutes.parentChildDetail}/${data.children[i].childId}',
                      ),
                      onStartLearning: () async {
                        await context
                            .read<ParentDashboardCubit>()
                            .switchToChild(data.children[i].childId);
                        if (context.mounted) context.go(AppRoutes.home);
                      },
                    )
                        .animate(delay: Duration(milliseconds: i * 100))
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1, end: 0),
                    childCount: data.children.length,
                  ),
                ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
      ],
    );
  }
}

// ── Parent header ─────────────────────────────────────────────────
class _ParentHeader extends StatelessWidget {
  final String parentName;
  final VoidCallback onAdd;
  final VoidCallback onSettings;
  final VoidCallback onLogout;
  final VoidCallback onGenerateLink;

  const _ParentHeader({
    required this.parentName,
    required this.onAdd,
    required this.onSettings,
    required this.onLogout,
    required this.onGenerateLink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.xl),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${parentName.split(' ').first}! 👋',
                          style: AppTextStyles.headingLarge
                              .copyWith(color: Colors.white),
                        ),
                        Text(
                          'Here\'s how your kids are doing',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.more_vert_rounded,
                          color: Colors.white),
                    ),
                    onSelected: (v) {
                      if (v == 'add') onAdd();
                      if (v == 'settings') onSettings();
                      if (v == 'logout') onLogout();
                      if (v == 'link') onGenerateLink();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'link',
                          child: ListTile(
                            leading: Icon(Icons.link_rounded),
                            title: Text('Copy invite link'),
                            contentPadding: EdgeInsets.zero,
                          )),
                      const PopupMenuItem(
                          value: 'add',
                          child: ListTile(
                            leading: Icon(Icons.person_add_rounded),
                            title: Text('Add another child'),
                            contentPadding: EdgeInsets.zero,
                          )),
                      const PopupMenuItem(
                          value: 'settings',
                          child: ListTile(
                            leading: Icon(Icons.settings_rounded),
                            title: Text('Settings'),
                            contentPadding: EdgeInsets.zero,
                          )),
                      const PopupMenuItem(
                          value: 'logout',
                          child: ListTile(
                            leading:
                                Icon(Icons.logout_rounded, color: Colors.red),
                            title: Text('Log out',
                                style: TextStyle(color: Colors.red)),
                            contentPadding: EdgeInsets.zero,
                          )),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // Add child button
              Wrap(
                spacing: AppSpacing.md,
                children: [
                  GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.4), width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text('Add another child',
                              style: AppTextStyles.label
                                  .copyWith(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Child card ────────────────────────────────────────────────────
class _ChildCard extends StatelessWidget {
  final ChildSummaryModel child;
  final VoidCallback onViewProgress;
  final VoidCallback onStartLearning;

  const _ChildCard({
    required this.child,
    required this.onViewProgress,
    required this.onStartLearning,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = child.overallProgressPct >= 70
        ? AppColors.green
        : child.overallProgressPct >= 40
            ? AppColors.teal
            : AppColors.coral;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.floating,
      ),
      child: Column(
        children: [
          // ── Top: name + avatar + screen time ──────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: progressColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: progressColor.withOpacity(0.3), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      child.displayName[0].toUpperCase(),
                      style: AppTextStyles.headingLarge
                          .copyWith(color: progressColor),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Name + streak
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(child.displayName,
                          style: AppTextStyles.headingSmall),
                      if (child.streakDays > 0)
                        Row(
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 3),
                            Text('${child.streakDays} day streak',
                                style: AppTextStyles.bodySmall),
                          ],
                        ),
                    ],
                  ),
                ),

                // Nothing here counts points. The app has never had any,
                // and the badge that used to sit here read total_points
                // from a response that has never carried it — every
                // dashboard load threw on it.
              ],
            ),
          ),

          // ── Screen time bar ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _ScreenTimeBar(child: child),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Progress bar ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Learning Progress', style: AppTextStyles.label),
                    Text(
                      '${child.lessonsCompleted}/${child.totalLessons} lessons',
                      style: AppTextStyles.label.copyWith(color: progressColor),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: child.overallProgressPct / 100,
                    backgroundColor: progressColor.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation(progressColor),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── This week's promise ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _PromiseRow(
              child: child,
              onTap: () => context.push(
                '${AppRoutes.parentPromise}/${child.childId}',
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Action buttons ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewProgress,
                    icon: const Icon(Icons.bar_chart_rounded, size: 16),
                    label: const Text('Progress'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.teal,
                      side: const BorderSide(color: AppColors.teal, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      minimumSize: const Size(0, AppSizes.minTouchTarget),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: child.isLimitReached ? null : onStartLearning,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(child.isLimitReached
                        ? '⏰ Limit reached'
                        : 'Start Learning'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.border,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      elevation: 0,
                      minimumSize: const Size(0, AppSizes.minTouchTarget),
                    ),
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

/// What this week's promise is doing, in one line.
///
/// Four states, and the order they are checked in is the point: a kept
/// week comes before everything else, because it is the only one with a
/// deadline attached to it in the real world. A parent who reads this
/// line on Sunday morning and learns on Sunday evening has already let
/// their child down.
class _PromiseRow extends StatelessWidget {
  final ChildSummaryModel child;
  final VoidCallback onTap;

  const _PromiseRow({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (icon, colour, title, subtitle) = switch (child) {
      final c when c.keptTheWeek => (
          Icons.celebration_rounded,
          AppColors.coral,
          '${c.displayName} kept their week',
          c.promiseText ?? 'They finished what they set out to do.',
        ),
      final c when c.promiseWanted => (
          Icons.favorite_border_rounded,
          AppColors.teal,
          '${c.displayName} set themselves a goal',
          'Promise them something for keeping it.',
        ),
      final c when c.promiseText != null => (
          Icons.handshake_rounded,
          AppColors.teal,
          'You promised',
          c.promiseText!,
        ),
      _ => (
          Icons.handshake_outlined,
          AppColors.textSecondary,
          'No promise this week',
          'Tap to make one.',
        ),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colour.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: colour),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.label),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 22, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Screen time bar ───────────────────────────────────────────────
class _ScreenTimeBar extends StatelessWidget {
  final ChildSummaryModel child;
  const _ScreenTimeBar({required this.child});

  @override
  Widget build(BuildContext context) {
    final pct = (child.minutesToday / child.maxDailyMinutes).clamp(0.0, 1.0);
    final color = child.isLimitReached ? AppColors.coral : AppColors.teal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.timer_rounded, color: color, size: 14),
                const SizedBox(width: 4),
                Text('Screen time today', style: AppTextStyles.label),
              ],
            ),
            Text(
              '${child.minutesToday.toInt()} / ${child.maxDailyMinutes} min',
              style: AppTextStyles.label.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────
class _EmptyChildren extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyChildren({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xxl),
        const Text('👶', style: TextStyle(fontSize: 64)),
        const SizedBox(height: AppSpacing.lg),
        Text('No children yet',
            style: AppTextStyles.headingMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Text(
          "Add your child's account to start tracking their learning journey.",
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.person_add_rounded),
          label: const Text("Add My Child"),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.coral,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
        ),
      ],
    );
  }
}
