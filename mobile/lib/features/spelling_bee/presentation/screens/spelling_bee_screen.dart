import 'package:flutter/material.dart';
import '../../../../core/mascot/kiki.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/session/day_plan.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../cubit/spelling_bee_cubit.dart';
import '../cubit/spelling_bee_state.dart';
import '../widgets/letter_tile.dart';
import '../widgets/round_result_overlay.dart';
import '../widgets/spelling_bee_final_screen.dart';

class SpellingBeeScreen extends StatelessWidget {
  const SpellingBeeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SpellingBeeCubit.create(),
      child: const _SpellingBeeView(),
    );
  }
}

/// The game is over, so the day moves on by itself.
///
/// This is the last activity in the plan, so in practice it leads to the
/// day's ending — but it asks the runner rather than routing there
/// directly, because what comes after an activity is the runner's decision
/// and not this screen's.
Future<void> _handOnToNext(BuildContext context) async {
  final next = await getIt<DayRunner>().advance(DayActivity.spellingBee);
  if (!context.mounted) return;
  context.go(next);
}

class _SpellingBeeView extends StatelessWidget {
  const _SpellingBeeView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SpellingBeeCubit, SpellingBeeState>(
      builder: (context, state) {
        if (state is SpellingBeeDone) {
          return SpellingBeeFinalScreen(
            state: state,
            onPlayAgain: () => context.read<SpellingBeeCubit>().restartGame(),
            onGoHome: () => _handOnToNext(context),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              _GameContent(state: state),

              if (state is SpellingBeeResult)
                RoundResultOverlay(
                  state: state,
                  onNext: () => context.read<SpellingBeeCubit>().nextRound(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GameContent extends StatelessWidget {
  final SpellingBeeState state;
  const _GameContent({required this.state});

  @override
  Widget build(BuildContext context) {
    // Initial — show start screen
    if (state is SpellingBeeInitial) {
      return _StartView();
    }

    if (state is! SpellingBeeReady && state is! SpellingBeeResult) {
      return const Center(child: CircularProgressIndicator());
    }

    final ready = state is SpellingBeeReady
        ? state as SpellingBeeReady
        : (state as SpellingBeeResult).let((_) => null);

    if (ready == null) return const SizedBox();

    return SafeArea(
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────
          _GameHeader(
            round: ready.round,
            totalRounds: ready.totalRounds,
            score: ready.score,
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Listen button ─────────────────────────────────────
          _ListenButton(
            hasPlayed: ready.hasPlayedAudio,
            onTap: () => context.read<SpellingBeeCubit>().playWordAudio(),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: AppSpacing.xl),

          // ── Answer slots ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _AnswerRow(state: ready),
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            ready.hasPlayedAudio
                ? 'Tap letters to spell the word!'
                : 'Listen first, then spell!',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ).animate().fadeIn(duration: 400.ms),

          const Spacer(),

          // ── Letter tile bank ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _LetterBank(state: ready),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Action buttons row ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _ActionButtons(state: ready),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

// ── Header with round + score ─────────────────────────────────────
class _GameHeader extends StatelessWidget {
  final int round;
  final int totalRounds;
  final int score;

  const _GameHeader({
    required this.round,
    required this.totalRounds,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go(AppRoutes.home),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_rounded,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spelling Bee 🐝',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.purple,
                  ),
                ),
                Text(
                  'Round $round of $totalRounds',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.yellow.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: AppColors.yellow.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Text('⭐', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  '$score pts',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.orange,
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

// ── Listen button ─────────────────────────────────────────────────
class _ListenButton extends StatelessWidget {
  final bool hasPlayed;
  final VoidCallback onTap;

  const _ListenButton({required this.hasPlayed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.purple, Color(0xFF9333EA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: [
            BoxShadow(
              color: AppColors.purple.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.volume_up_rounded, color: Colors.white, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Text(
              hasPlayed ? 'Hear Again 🔊' : 'Listen! 👂',
              style: AppTextStyles.buttonLarge,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Answer slots row ──────────────────────────────────────────────
class _AnswerRow extends StatelessWidget {
  final SpellingBeeReady state;
  const _AnswerRow({required this.state});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      alignment: WrapAlignment.center,
      children: List.generate(state.word.length, (i) {
        return AnswerSlot(
          index: i,
          letter: state.placedLetters[i],
          onTap: () => context.read<SpellingBeeCubit>().removeLetterAt(i),
        );
      }),
    );
  }
}

// ── Letter tile bank ──────────────────────────────────────────────
class _LetterBank extends StatelessWidget {
  final SpellingBeeReady state;
  const _LetterBank({required this.state});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      alignment: WrapAlignment.center,
      children: List.generate(state.shuffledLetters.length, (i) {
        final letter = state.shuffledLetters[i];
        // Check if this letter has been placed already
        // Count how many times it appears in placed vs total
        final placedCount =
            state.placedLetters.where((l) => l == letter).length;
        final availableCount =
            state.shuffledLetters.where((l) => l == letter).length;
        final isUsed = placedCount >= availableCount;

        return LetterTile(
          letter: letter,
          isPlaced: isUsed,
          animationIndex: i,
          onTap: isUsed
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  context.read<SpellingBeeCubit>().placeLetter(letter);
                },
        );
      }),
    );
  }
}

// ── Action buttons ────────────────────────────────────────────────
class _ActionButtons extends StatelessWidget {
  final SpellingBeeReady state;
  const _ActionButtons({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            context.read<SpellingBeeCubit>().removeLast();
          },
          child: Container(
            width: AppSizes.minTouchTarget,
            height: AppSizes.minTouchTarget,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: const Icon(
              Icons.backspace_outlined,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ),
        ),

        const SizedBox(width: AppSpacing.md),

        // Check / Submit
        Expanded(
          child: GestureDetector(
            onTap: state.isComplete
                ? () {
                    HapticFeedback.heavyImpact();
                    context.read<SpellingBeeCubit>().checkAnswer();
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: AppSizes.minTouchTarget,
              decoration: BoxDecoration(
                color: state.isComplete
                    ? AppColors.purple
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: state.isComplete
                    ? [
                        BoxShadow(
                          color: AppColors.purple.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  state.isComplete ? 'Check Answer ✓' : 'Fill all letters',
                  style: AppTextStyles.buttonLarge.copyWith(
                    color: state.isComplete
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Start screen ──────────────────────────────────────────────────
class _StartView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  onTap: () => context.go(AppRoutes.home),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                  ),
                ),
              ),
              const Spacer(),
              const Kiki(size: 180, mood: KikiMood.celebrating)
                  .animate()
                  .scale(
                    begin: const Offset(0.7, 0.7),
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                  ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Spelling Bee 🐝',
                style: AppTextStyles.displayMedium.copyWith(
                  color: AppColors.purple,
                ),
                textAlign: TextAlign.center,
              ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Listen to a word, then tap the\nletters to spell it correctly!',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ).animate(delay: 300.ms).fadeIn(duration: 400.ms),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: AppSizes.minTouchTarget,
                child: ElevatedButton(
                  onPressed: () => context.read<SpellingBeeCubit>().startGame(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    elevation: 0,
                    shadowColor: AppColors.purple.withValues(alpha: 0.4),
                  ),
                  child: const Text(
                    "Let's Play! 🚀",
                    style: AppTextStyles.buttonLarge,
                  ),
                ),
              ).animate(delay: 400.ms).fadeIn(duration: 400.ms),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
