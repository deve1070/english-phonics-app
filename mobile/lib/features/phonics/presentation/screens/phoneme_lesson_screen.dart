import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/session/day_plan.dart';
import '../../../../core/session/learning_cursor.dart';
import '../../../lessons/presentation/widgets/session_summary_sheet.dart';
import '../../../home/presentation/widgets/level_style.dart';
import '../cubit/phonics_cubit.dart';
import '../cubit/phonics_state.dart';
import '../../domain/entities/lesson_entity.dart';
import 'lesson_stage.dart';
import '../widgets/phoneme_hero_card.dart';
import '../widgets/exercise_card.dart';
import '../widgets/phoneme_quiz_widget.dart';

class PhonemeLessonScreen extends StatelessWidget {
  final int lessonId;

  /// Where to pick this lesson up, when arriving from a stored cursor.
  /// Null when the lesson is being opened from the start.
  final int? resumePhonemeId;
  final String? resumeStage;

  const PhonemeLessonScreen({
    super.key,
    required this.lessonId,
    this.resumePhonemeId,
    this.resumeStage,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PhonicsCubit.create()..loadLesson(lessonId),
      child: _PhonemeLessonView(
        lessonId: lessonId,
        resumePhonemeId: resumePhonemeId,
        resumeStage: resumeStage,
      ),
    );
  }
}

class _PhonemeLessonView extends StatefulWidget {
  final int lessonId;
  final int? resumePhonemeId;
  final String? resumeStage;

  const _PhonemeLessonView({
    required this.lessonId,
    this.resumePhonemeId,
    this.resumeStage,
  });

  @override
  State<_PhonemeLessonView> createState() => _PhonemeLessonViewState();
}

class _PhonemeLessonViewState extends State<_PhonemeLessonView> {
  late LessonStage _stage = LessonStage.named(widget.resumeStage);
  int _lastPhonemeIndex = -1; // track phoneme changes

  /// True until the cubit has been pointed at the phoneme we resumed to,
  /// so the listener below does not treat that first arrival as the child
  /// moving on and reset them to the start of it.
  bool _awaitingResume = false;

  @override
  void initState() {
    super.initState();
    _awaitingResume = widget.resumePhonemeId != null;
  }

  /// Remembers the step before showing it.
  ///
  /// Written on every move rather than on leaving: this app is closed by
  /// the battery, by Android reclaiming memory, or by a parent taking the
  /// phone away mid-sentence, and none of those run an exit handler.
  void _advanceTo(LessonStage stage) {
    setState(() => _stage = stage);
    _remember(stage);
  }

  void _remember(LessonStage stage) {
    final state = context.read<PhonicsCubit>().state;
    if (state is! PhonicsLoaded) return;
    getIt<CursorStore>().save(LearningCursor(
      lessonId: widget.lessonId,
      phonemeId: state.currentPhoneme?.id,
      stage: stage.name,
    ));
  }

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
          // Arriving from a stored cursor: point the lesson at the phoneme
          // the child stopped on before anything below can conclude they
          // have moved and send them back to its first step.
          if (_awaitingResume) {
            _awaitingResume = false;
            final target = widget.resumePhonemeId;
            final index = target == null
                ? -1
                : state.lesson.phonemes.indexWhere((p) => p.id == target);

            if (index >= 0) {
              // Claim the destination *before* jumping. goToPhoneme emits
              // immediately, and this listener runs again on the result: if
              // _lastPhonemeIndex still held the index we started from, that
              // second pass would read the jump as the child moving to a new
              // sound and send them back to the first step of it — undoing
              // the resume, every launch, for exactly the children who had
              // got furthest into a sound.
              _lastPhonemeIndex = index;
              context.read<PhonicsCubit>().goToPhoneme(target!);
              return;
            }

            // The sound is not in this lesson any more — a cursor can
            // outlive a curriculum change. Start the lesson properly rather
            // than opening a different sound at the step they reached in
            // the old one.
            _lastPhonemeIndex = state.currentPhonemeIndex;
            if (_stage != LessonStage.phonemeIntro) {
              setState(() => _stage = LessonStage.phonemeIntro);
            }
            return;
          }

          // When phoneme changes (next/prev), reset to intro stage
          if (state.currentPhonemeIndex != _lastPhonemeIndex) {
            _lastPhonemeIndex = state.currentPhonemeIndex;
            if (_stage != LessonStage.phonemeIntro) {
              setState(() => _stage = LessonStage.phonemeIntro);
            }
            // A new sound is a new position worth remembering, and it is
            // reached without passing through _advanceTo.
            _remember(LessonStage.phonemeIntro);
          }

          // Gate passed → advance to quiz
          if (state.phonemeUnlocked &&
              _stage == LessonStage.gate &&
              !state.isGateScoring) {
            _advanceTo(LessonStage.quiz);
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
  final LessonStage stage;
  final void Function(LessonStage) onAdvance;

  /// Routed through the parent so leaving always closes the session, rather
  /// than depending on whether go_router's pop happens to consult PopScope.
  final VoidCallback onLeave;

  const _LoadedView({
    required this.state,
    required this.stage,
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
            // "⭐ Level 1", "1 of 5 sounds", a row of progress dots and a
            // four-icon stage rail used to sit here, above the letter. All
            // four report on the curriculum; none of them is something a
            // child can act on, and together they were the first thing on
            // the screen. Where a child is up to belongs in the parent
            // dashboard. What belongs here is the sound.
            centerTitle: true,
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

  Widget _stageContent(
      BuildContext context, Color color, PhonemeEntity phoneme) {
    switch (stage) {
      case LessonStage.phonemeIntro:
        return Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            PhonemeHeroCard(
              phoneme: phoneme,
              color: color,
              isPlayingAudio: state.isPlayingAudio,
              onPlayAudio: () =>
                  context.read<PhonicsCubit>().playPhonemeAudio(phoneme.id),
            ),
            // A drawn mouth used to sit here, captioned "watch carefully".
            // It only ever knew one sound of the ninety in the curriculum;
            // for the rest it sat closed and still while a child was told
            // to copy it. Nothing is better than that. What belongs here is
            // a real mouth on video — correct and natural by construction,
            // which no drawn model of ours would be — and that waits on
            // someone filming the sounds, not on code.
            const SizedBox(height: AppSpacing.xxl),
            _NavRow(
              // The label carried a 🎤 emoji next to a mic icon, so the
              // button showed two microphones.
              state: state,
              color: color,
              nextLabel: "I'm ready!",
              nextIcon: Icons.mic_rounded,
              onNext: () => onAdvance(LessonStage.gate),
            ),
          ],
        );

      case LessonStage.gate:
        return _GateSection(
          state: state,
          phoneme: phoneme,
          color: color,
        );

      case LessonStage.quiz:
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
              onComplete: () => onAdvance(LessonStage.exercises),
              onPlaySound: (id) =>
                  context.read<PhonicsCubit>().playPhonemeAudio(id),
              isPlayingAudio: state.isPlayingAudio,
              questionCount:
                  learnedPhonemes.length < 4 ? learnedPhonemes.length : 4,
            ),
          ],
        );

      case LessonStage.exercises:
        return _ExercisesSection(
          state: state,
          color: color,
          phoneme: phoneme,
        );
    }
  }
}

// ── Gate section ──────────────────────────────────────────────────
class _GateSection extends StatelessWidget {
  final PhonicsLoaded state;
  final PhonemeEntity phoneme;
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
              phoneme.letters,
              style: AppTextStyles.phonemeDisplay.copyWith(
                color: color,
                fontSize: phoneme.letters.length > 8 ? 48 : 64,
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

/// The last sound of the lesson is done, so the day moves on.
///
/// Two things have to happen here and neither is navigation. The cursor is
/// moved onto the next lesson — left pointing inside the one just
/// finished, tomorrow's launch would resume its final sound and hand the
/// child work they have already done, every day, for as long as they kept
/// using the app. And the day's plan is told the lesson is finished, which
/// is what makes the next activity arrive by itself rather than having to
/// be found.
Future<void> _finishLesson(BuildContext context) async {
  final nextLessonId = await context.read<PhonicsCubit>().finishLesson();

  final cursor = getIt<CursorStore>();
  if (nextLessonId == null) {
    // The end of the curriculum. Nothing to resume into, and a cursor
    // pointing at a lesson that no longer follows would be worse than none.
    await cursor.clear();
  } else {
    await cursor.save(LearningCursor(
      lessonId: nextLessonId,
      stage: LessonStage.phonemeIntro.name,
    ));
  }

  final next = await getIt<DayRunner>().advance(DayActivity.lesson);
  if (!context.mounted) return;
  context.go(next);
}

// ── Exercises section ─────────────────────────────────────────────
class _ExercisesSection extends StatelessWidget {
  final PhonicsLoaded state;
  final Color color;
  final PhonemeEntity phoneme;

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
              ? () => _finishLesson(context)
              : () => context.read<PhonicsCubit>().nextPhoneme(),
        ),
      ],
    );
  }
}

class _GenerateButton extends StatelessWidget {
  final PhonicsLoaded state;
  final Color color;
  final PhonemeEntity phoneme;

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
    // One action. A "Previous" button sat beside this one, greyed out on
    // the first sound and offering to go backwards on every other — a
    // second thing to weigh up before doing the only thing there is to do.
    return SizedBox(
      width: double.infinity,
      child: _NavButton(
        label: nextLabel,
        icon: nextIcon,
        color: color,
        isFilled: true,
        isEnabled: true,
        onTap: onNext,
      ),
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
