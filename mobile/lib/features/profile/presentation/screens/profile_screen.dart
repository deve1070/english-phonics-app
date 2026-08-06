import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/auth/parent_gate.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../progress/presentation/cubit/progress_cubit.dart';
import '../../../progress/presentation/cubit/progress_state.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileCubit.create()..load(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state is ProfileLoggedOut) {
          context.go(AppRoutes.login);
        }
      },
      builder: (context, state) {
        if (state is ProfileLoading || state is ProfileInitial) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.coral),
              ),
            ),
          );
        }
        if (state is ProfileError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('😅', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text(state.message, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<ProfileCubit>().load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (state is ProfileLoaded) {
          return _LoadedView(user: state.user);
        }
        return const SizedBox();
      },
    );
  }
}

class _LoadedView extends StatelessWidget {
  final UserEntity user;
  const _LoadedView({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Hero header ────────────────────────────────────────
          SliverToBoxAdapter(
            child: _ProfileHeader(user: user),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // What they have done. This page used to hold nothing but
                  // settings — three grown-up controls under a child's own
                  // name and face — while what they had actually earned sat
                  // behind a separate Progress tab.
                  const _MyThings()
                      .animate(delay: 150.ms)
                      .fadeIn(duration: 400.ms),

                  const SizedBox(height: AppSpacing.xl),

                  _SettingsItem(
                    icon: Icons.volume_up_rounded,
                    label: 'Sound Effects',
                    color: AppColors.yellow,
                    onTap: () {},
                  ).animate(delay: 250.ms).fadeIn(duration: 400.ms),

                  const SizedBox(height: AppSpacing.xl),

                  // Everything past here is for an adult, and every one of
                  // them is behind the gate. Logging out is the sharpest:
                  // signing back in needs a phone number, so a child who
                  // taps it locks themselves out of their own app.
                  Text('For grown-ups', style: AppTextStyles.label)
                      .animate(delay: 300.ms)
                      .fadeIn(duration: 400.ms),

                  const SizedBox(height: AppSpacing.md),

                  _SettingsItem(
                    icon: Icons.family_restroom_rounded,
                    label: 'Parent Dashboard',
                    color: AppColors.teal,
                    onTap: () async {
                      if (await ParentGate.open(context) && context.mounted) {
                        context.push(AppRoutes.parentDashboard);
                      }
                    },
                  ).animate(delay: 340.ms).fadeIn(duration: 400.ms),

                  const SizedBox(height: AppSpacing.md),

                  _SettingsItem(
                    icon: Icons.logout_rounded,
                    label: 'Log Out',
                    color: AppColors.coral,
                    onTap: () async {
                      if (await ParentGate.open(context) && context.mounted) {
                        _showLogoutDialog(context);
                      }
                    },
                  ).animate(delay: 380.ms).fadeIn(duration: 400.ms),

                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: const Text('Log Out?'),
        content: Text(
          'Are you sure you want to log out?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ProfileCubit>().logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coral,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}

// ── What the child has earned ──────────────────────────────────────
/// Counts up, never down.
///
/// The Progress tab this replaces opened on "0 Lessons Done", "0
/// Exercises", "Overall Completion 0%" and "0 of 0 exercises completed",
/// and the collection on "0 of 90 awake" over two dozen grey eggs. The
/// first thing the app told a child about themselves was four zeroes and
/// ninety things they had not done — to a child whose reason for being
/// here is coming to believe they can achieve something.
///
/// So: what they have, and nothing they lack. Before there is anything to
/// count, an invitation rather than a nought.
class _MyThings extends StatelessWidget {
  const _MyThings();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProgressCubit.create()..load(),
      child: BlocBuilder<ProgressCubit, ProgressState>(
        builder: (context, state) {
          final loaded = state is ProgressLoaded ? state : null;
          final practised = loaded?.practicedCount ?? 0;
          final lessons = loaded?.completedLessons ?? 0;
          final streak = loaded?.streakDays ?? 0;
          final nothingYet = practised == 0 && lessons == 0 && streak == 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My things', style: AppTextStyles.headingSmall),
              const SizedBox(height: AppSpacing.md),

              if (nothingYet)
                Text(
                  'Practise a sound and it will show up here.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                )
              else
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    if (practised > 0)
                      _Tally(
                        value: practised,
                        label: practised == 1 ? 'sound' : 'sounds',
                        colour: AppColors.honey,
                      ),
                    if (lessons > 0)
                      _Tally(
                        value: lessons,
                        label: lessons == 1 ? 'lesson' : 'lessons',
                        colour: AppColors.leaf,
                      ),
                    if (streak > 0)
                      _Tally(
                        value: streak,
                        label: streak == 1 ? 'day' : 'days',
                        colour: AppColors.coral,
                      ),
                  ],
                ),

              const SizedBox(height: AppSpacing.lg),

              // The one place a child is meant to browse: things they have
              // already earned. Rereading a story they liked is reading
              // practice, so it is carved out of the rule on purpose.
              //
              // Full width rather than side by side. _SettingsItem puts its
              // label in an Expanded between a 40px icon and an arrow, so
              // at half a phone's width there are about sixty pixels left
              // for the words.
              _SettingsItem(
                icon: Icons.auto_awesome_rounded,
                label: 'My Sounds',
                color: AppColors.honey,
                onTap: () => context.push(AppRoutes.collection),
              ),
              _SettingsItem(
                icon: Icons.menu_book_rounded,
                label: 'My Stories',
                color: AppColors.sky,
                onTap: () => context.push(AppRoutes.stories),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  final int value;
  final String label;
  final Color colour;

  const _Tally({
    required this.value,
    required this.label,
    required this.colour,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$value',
            style: AppTextStyles.headingMedium.copyWith(color: colour),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

// ── Profile header ─────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final UserEntity user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.xl),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
          child: Column(
            children: [
              // Avatar with initial
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Center(
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: AppTextStyles.displayMedium.copyWith(
                      color: Colors.white,
                      fontSize: 40,
                    ),
                  ),
                ),
              ).animate().scale(
                    begin: const Offset(0.7, 0.7),
                    duration: 500.ms,
                    curve: Curves.elasticOut,
                  ),

              const SizedBox(height: AppSpacing.md),

              // Name
              Text(
                user.name,
                style: AppTextStyles.headingLarge.copyWith(color: Colors.white),
              ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

              // Username
              Text(
                '@${user.userName}',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: Colors.white.withOpacity(0.8)),
              ).animate(delay: 150.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: AppSpacing.sm),

              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  user.role.toUpperCase() == 'ADMIN'
                      ? '⚙️ Admin'
                      : '🎓 Student',
                  style: AppTextStyles.label.copyWith(color: Colors.white),
                ),
              ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}



// ── Settings item ──────────────────────────────────────────────────
class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(label, style: AppTextStyles.bodyLarge),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
