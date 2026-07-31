import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/di/injection.dart';
import '../../../lessons/presentation/widgets/session_summary_sheet.dart';
import '../../../home/presentation/widgets/level_style.dart';
import '../cubit/phonics_cubit.dart';
import '../cubit/phonics_state.dart';
import '../widgets/phoneme_hero_card.dart';
import '../widgets/mouth_animation_widget.dart';
import '../widgets/exercise_card.dart';
import '../widgets/phoneme_progress_dots.dart';
import '../widgets/phoneme_quiz_widget.dart';

enum _LessonStage { phonemeIntro, gate, quiz, exercises }

class PhonemeLessonScreen extends StatelessWidget {
  final int lessonId;
  const PhonemeLessonScreen({super.key, required this.lessonId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PhonicsCubit.create()..loadLesson(lessonId),
      child: const _PhonemeLessonView(),
    );
  }
}

class _PhonemeLessonView extends StatefulWidget {
  const _PhonemeLessonView();
  @override
  State<_PhonemeLessonView> createState() => _PhonemeLessonViewState();
}

class _PhonemeLessonViewState extends State<_PhonemeLessonView> {
  _LessonStage _stage = _LessonStage.phonemeIntro;
  int _lastPhonemeIndex = -1; // track phoneme changes
  // Key to access MouthAnimationWidget's state
  final GlobalKey<MouthAnimationWidgetState> _mouthKey =
      GlobalKey<MouthAnimationWidgetState>();

  void _advanceTo(_LessonStage stage) => setState(() => _stage = stage);

  /// Set once the summary has been shown, so the second pop goes through.
  ///
  /// Without it the pop inside [_leaveLesson] would be intercepted by this
  /// same PopScope and loop forever.
  bool _readyToLeave = false;

  /// Closes the sitting with a summary instead of just vanishing.
  ///
  /// Hooked to leaving the lesson rather than to any one exercise, since a
  /// session spans several. Skipped when nothing was attempted — a child
  /// who opened a lesson and immediately backed out has nothing to
  /// celebrate, and a summary of zero would cheapen every real one.
  Future<void> _leaveLesson() async {
    if (_readyToLeave) return;

    final tracker = getIt<SessionTracker>();
    final tally = tracker.build();

    if (!tally.isEmpty) {
      tracker.reset();
      if (!mounted) return;
      await SessionSummarySheet.show(context, tally: tally);
    }

    if (!mounted) return;
    setState(() => _readyToLeave = true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Blocks the pop so the summary can run before the route is torn down.
    // Covers the system back gesture, which on Android is how most children
    // will actually leave; the app bar button calls _leaveLesson directly.
    return PopScope(
      canPop: _readyToLeave,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _leaveLesson();
      },
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return BlocConsumer<PhonicsCubit, PhonicsState>(
      listener: (context, state) {
        // FIX: errors shown as snackbar — do NOT reset stage
        if (state is PhonicsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.coral,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }

        if (state is PhonicsLoaded) {
          // When phoneme changes (next/prev), reset to intro stage
          if (state.currentPhonemeIndex != _lastPhonemeIndex) {
            _lastPhonemeIndex = state.currentPhonemeIndex;
            if (_stage != _LessonStage.phonemeIntro) {
              setState(() => _stage = _LessonStage.phonemeIntro);
            }
          }

          // Gate passed → advance to quiz
          if (state.phonemeUnlocked &&
              _stage == _LessonStage.gate &&
              !state.isGateScoring) {
            _advanceTo(_LessonStage.quiz);
          }
        }
      },
      // FIX: only rebuild UI for PhonicsLoaded/Loading — ignore PhonicsError
      // (error is handled by listener as snackbar)
      buildWhen: (prev, curr) =>
          curr is PhonicsLoaded ||
          curr is PhonicsLoading ||
          curr is PhonicsInitial,
      builder: (context, state) {
        if (state is PhonicsLoading || state is PhonicsInitial) {
          return const _LoadingView();
        }
        if (state is PhonicsLoaded) {
          return _LoadedView(
            state: state,
            stage: _stage,
            mouthKey: _mouthKey,
            onAdvance: _advanceTo,
            onLeave: _leaveLesson,
          );
        }
        return const _LoadingView();
      },
    );
  }
}

// ── Loaded view ───────────────────────────────────────────────────
class _LoadedView extends StatelessWidget {
  final PhonicsLoaded state;
  final _LessonStage stage;
  final GlobalKey<MouthAnimationWidgetState> mouthKey;
  final void Function(_LessonStage) onAdvance;

  /// Routed through the parent so leaving always closes the session, rather
  /// than depending on whether go_router's pop happens to consult PopScope.
  final VoidCallback onLeave;

  const _LoadedView({
    required this.state,
    required this.stage,
    required this.mouthKey,
    required this.onAdvance,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final phoneme = state.currentPhoneme;
    if (phoneme == null) {
      return const Scaffold(
          body: Center(child: Text('No phonemes in this lesson yet.')));
    }

    final color = LevelStyle.color(state.lesson.level);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.surfaceVariant, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_rounded,
                    size: 18, color: AppColors.textPrimary),
              ),
              onPressed: onLeave,
            ),
            title: Column(
              children: [
                Text(
                  '${LevelStyle.emoji(state.lesson.level)} ${LevelStyle.label(state.lesson.level)}',
                  style: AppTextStyles.headingSmall,
                ),
                Text(
                  '${state.currentPhonemeIndex + 1} of ${state.lesson.phonemes.length} sounds',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(24),
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: PhonemeProgressDots(
                  total: state.lesson.phonemes.length,
                  current: state.currentPhonemeIndex,
                  color: color,
                ),
              ),
            ),
          ),

          // Stage indicator
          SliverToBoxAdapter(
            child: _StageIndicator(stage: stage, color: color),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: KeyedSubtree(
                  key: ValueKey(stage),
                  child: _stageContent(context, color, phoneme),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        ],
      ),
    );
  }

  Widget _stageContent(BuildContext context, Color color, phoneme) {
    switch (stage) {
      case _LessonStage.phonemeIntro:
        return Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            PhonemeHeroCard(
              phoneme: phoneme,
              color: color,
              isPlayingAudio: state.isPlayingAudio,
              // FIX: play audio AND trigger mouth animation simultaneously
              onPlayAudio: () {
                context.read<PhonicsCubit>().playPhonemeAudio(phoneme.id);
                // Trigger mouth animation in sync with audio
                mouthKey.currentState?.triggerAnimation();
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            // FIX: MouthAnimationWidget no longer needs a tap — it receives
            // triggerAnimation() calls from the play button above
            MouthAnimationWidget(
              key: mouthKey,
              phonemeType: phoneme.type,
              phonemeSymbol: phoneme.symbol,
              color: color,
            ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
            const SizedBox(height: AppSpacing.xl),
            _NavRow(
              state: state,
              color: color,
              nextLabel: "I'm ready! 🎤",
              nextIcon: Icons.mic_rounded,
              onNext: () => onAdvance(_LessonStage.gate),
            ),
          ],
        );

      case _LessonStage.gate:
        return _GateSection(
          state: state,
          phoneme: phoneme,
          color: color,
        );

      case _LessonStage.quiz:
        final learnedPhonemes = state.lesson.phonemes
            .where((p) => p.order <= phoneme.order)
            .toList();
        return Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.teal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                    color: AppColors.teal.withOpacity(0.2), width: 1.5),
              ),
              child: Text(
                '🎮 Quick Quiz — test what you know!',
                style:
                    AppTextStyles.headingSmall.copyWith(color: AppColors.teal),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PhonemeQuizSession(
              learnedPhonemes: learnedPhonemes,
              currentPhoneme: phoneme,
              onComplete: () => onAdvance(_LessonStage.exercises),
              onPlaySound: (id) =>
                  context.read<PhonicsCubit>().playPhonemeAudio(id),
              isPlayingAudio: state.isPlayingAudio,
              questionCount:
                  learnedPhonemes.length < 4 ? learnedPhonemes.length : 4,
            ),
          ],
        );

      case _LessonStage.exercises:
        return _ExercisesSection(
          state: state,
          color: color,
          phoneme: phoneme,
        );
    }
  }
}

// ── Stage indicator (Simplified & Centered) ───────────────────────
class _StageIndicator extends StatelessWidget {
  final _LessonStage stage;
  final Color color;
  const _StageIndicator({required this.stage, required this.color});

  @override
  Widget build(BuildContext context) {
    final stages = [
      Icons.hearing_rounded,
      Icons.mic_rounded,
      Icons.quiz_rounded,
      Icons.edit_rounded,
    ];
    final current = _LessonStage.values.indexOf(stage);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: Row(
        children: stages.asMap().entries.map((e) {
          final i = e.key;
          final icon = e.value;
          final isDone = i < current;
          final isActive = i == current;

          return Expanded(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? AppColors.green
                        : isActive
                            ? color
                            : AppColors.surfaceVariant,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                                color: color.withOpacity(0.35),
                                blurRadius: 8)
                          ]
                        : null,
                  ),
                  child: Icon(
                    isDone ? Icons.check_rounded : icon,
                    color: isDone || isActive
                        ? Colors.white
                        : AppColors.textSecondary,
                    size: 16,
                  ),
                ),
                if (i < stages.length - 1)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: i < current
                            ? AppColors.green.withOpacity(0.6)
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Gate section ──────────────────────────────────────────────────
class _GateSection extends StatelessWidget {
  final PhonicsLoaded state;
  final dynamic phoneme;
  final Color color;

  const _GateSection({
    required this.state,
    required this.phoneme,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xl),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xxl,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: color.withOpacity(0.25), width: 2),
          ),
          child: Center(
            child: Text(
              phoneme.dualCaseSymbol,
              style: AppTextStyles.phonemeDisplay.copyWith(
                color: color,
                fontSize: phoneme.dualCaseSymbol.length > 8 ? 48 : 64,
                fontFamily: 'PatrickHand',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        _GateRecordButton(state: state),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _GateRecordButton extends StatelessWidget {
  final PhonicsLoaded state;
  const _GateRecordButton({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isGateScoring) {
      return Column(children: [
        const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.teal), strokeWidth: 3),
        const SizedBox(height: AppSpacing.md),
        Text('Scoring...', style: AppTextStyles.bodyMedium),
      ]);
    }

    return Column(
      children: [
        GestureDetector(
          onTap: state.isGateRecording
              ? () => context.read<PhonicsCubit>().stopAndSubmitGate()
              : () => context.read<PhonicsCubit>().startGateRecording(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (state.isGateRecording)
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.coral.withOpacity(0.15)),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.4, 1.4),
                        duration: 800.ms)
                    .fadeOut(duration: 800.ms),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      state.isGateRecording ? AppColors.coral : AppColors.teal,
                  boxShadow: [
                    BoxShadow(
                      color: (state.isGateRecording
                              ? AppColors.coral
                              : AppColors.teal)
                          .withOpacity(0.45),
                      blurRadius: 24,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  state.isGateRecording
                      ? Icons.stop_rounded
                      : Icons.mic_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          state.isGateRecording ? 'Tap to stop recording' : 'Tap to record',
          style: AppTextStyles.bodyMedium.copyWith(
            color: state.isGateRecording
                ? AppColors.coral
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Exercises section ─────────────────────────────────────────────
class _ExercisesSection extends StatelessWidget {
  final PhonicsLoaded state;
  final Color color;
  final dynamic phoneme;

  const _ExercisesSection({
    required this.state,
    required this.color,
    required this.phoneme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Text('Practice Exercises', style: AppTextStyles.headingSmall),
            if (state.exercises.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text('${state.exercises.length}',
                    style: AppTextStyles.label.copyWith(color: color)),
              ),
            ],
            const Spacer(),
            _GenerateButton(state: state, color: color, phoneme: phoneme),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (state.isGeneratingExercises)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: Column(children: [
                CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.teal),
                    strokeWidth: 3),
                SizedBox(height: AppSpacing.md),
                Text('AI is generating exercises...'),
              ]),
            ),
          )
        else if (state.exercises.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: Column(children: [
                const Text('🎨', style: TextStyle(fontSize: 48)),
                const SizedBox(height: AppSpacing.md),
                Text('No exercises yet.',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                Text(
                    'Tap "Generate" above to create AI exercises for this sound.',
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center),
              ]),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: state.exercises.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final exercise = state.exercises[index];
              return ExerciseCard(
                exercise: exercise,
                color: color,
                lessonId: state.lesson.id,
                onTap: () => context.push(
                  '/lessons/${state.lesson.id}/exercise/${exercise.id}',
                  extra: {
                    'content': exercise.content,
                    'type': exercise.type,
                  },
                ),
              )
                  .animate(delay: Duration(milliseconds: 60 * index))
                  .fadeIn(duration: 300.ms)
                  .slideX(begin: 0.1, end: 0, duration: 300.ms);
            },
          ),
        const SizedBox(height: AppSpacing.xl),
        _NavRow(
          state: state,
          color: color,
          nextLabel: state.isLastPhoneme ? 'Finish Lesson 🏁' : 'Next Sound',
          nextIcon: state.isLastPhoneme
              ? Icons.flag_rounded
              : Icons.arrow_forward_rounded,
          onNext: state.isLastPhoneme
              ? () async {
                  final nextLessonId =
                      await context.read<PhonicsCubit>().finishLesson();
                  if (!context.mounted) return;
                  if (nextLessonId == null) {
                    context.go('/lessons');
                  } else {
                    context.go('/lessons/$nextLessonId');
                  }
                }
              : () => context.read<PhonicsCubit>().nextPhoneme(),
        ),
      ],
    );
  }
}

class _GenerateButton extends StatelessWidget {
  final PhonicsLoaded state;
  final Color color;
  final dynamic phoneme;

  const _GenerateButton(
      {required this.state, required this.color, required this.phoneme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: state.isGeneratingExercises
          ? null
          : () => context
              .read<PhonicsCubit>()
              .generateExercises(state.lesson.id, phoneme.id),
      child: AnimatedOpacity(
        opacity: state.isGeneratingExercises ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, color: color, size: 14),
              const SizedBox(width: 4),
              Text('Generate',
                  style:
                      AppTextStyles.label.copyWith(color: color, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Navigation row ────────────────────────────────────────────────
class _NavRow extends StatelessWidget {
  final PhonicsLoaded state;
  final Color color;
  final String nextLabel;
  final IconData nextIcon;
  final VoidCallback onNext;

  const _NavRow({
    required this.state,
    required this.color,
    required this.nextLabel,
    required this.nextIcon,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _NavButton(
            label: 'Previous',
            icon: Icons.arrow_back_rounded,
            color: AppColors.textSecondary,
            isEnabled: !state.isFirstPhoneme,
            onTap: () => context.read<PhonicsCubit>().previousPhoneme(),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 2,
          child: _NavButton(
            label: nextLabel,
            icon: nextIcon,
            color: color,
            isFilled: true,
            isEnabled: true,
            onTap: onNext,
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isFilled;
  final bool isEnabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isEnabled,
    required this.onTap,
    this.isFilled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: isEnabled ? 1.0 : 0.35,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: AppSizes.minTouchTarget,
          decoration: BoxDecoration(
            color: isFilled ? color : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: isFilled
                ? null
                : Border.all(color: color.withOpacity(0.3), width: 1.5),
            boxShadow: isFilled
                ? [
                    BoxShadow(
                        color: color.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isFilled)
                Icon(icon,
                    color: isEnabled ? color : AppColors.textSecondary,
                    size: 18),
              if (!isFilled) const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.buttonMedium.copyWith(
                  color: isFilled
                      ? Colors.white
                      : isEnabled
                          ? color
                          : AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              if (isFilled) const SizedBox(width: 6),
              if (isFilled) Icon(icon, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Loading view ──────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.coral),
          strokeWidth: 3,
        ),
      ),
    );
  }
}
