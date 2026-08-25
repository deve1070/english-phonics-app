import 'package:flutter/material.dart';
import '../../../../core/mascot/kiki.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../lessons/presentation/widgets/session_summary_sheet.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../cubit/pronunciation_cubit.dart';
import '../cubit/pronunciation_state.dart';
import '../widgets/mic_button.dart';
import '../widgets/score_result_card.dart';
import '../../../../core/theme/pressable.dart';

class PronunciationScreen extends StatelessWidget {
  final int exerciseId;
  final String exerciseContent;
  final String exerciseType;

  const PronunciationScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseContent,
    required this.exerciseType,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PronunciationCubit.create(),
      child: _PronunciationView(
        exerciseId: exerciseId,
        exerciseContent: exerciseContent,
        exerciseType: exerciseType,
      ),
    );
  }
}

class _PronunciationView extends StatelessWidget {
  final int exerciseId;
  final String exerciseContent;
  final String exerciseType;

  const _PronunciationView({
    required this.exerciseId,
    required this.exerciseContent,
    required this.exerciseType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
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
          onPressed: () => context.pop(),
        ),
        title: const Text('Pronunciation', style: AppTextStyles.headingSmall),
        centerTitle: true,
      ),
      body: BlocConsumer<PronunciationCubit, PronunciationState>(
        // Every scored attempt feeds the running tally the end-of-session
        // summary reports. Done here rather than in the cubit so the
        // session tracker stays out of the scoring logic.
        listenWhen: (prev, next) =>
            next is PronunciationScored && prev is! PronunciationScored,
        listener: (context, state) {
          if (state is PronunciationScored) {
            getIt<SessionTracker>().recordAttempt(
              score: state.score,
              sound: exerciseContent,
            );
          }
        },
        builder: (context, state) {
          if (state is PronunciationScored) {
            return _ScoredView(
              state: state,
              exerciseContent: exerciseContent,
              onTryAgain: () => context.read<PronunciationCubit>().reset(),
              onNext: () => context.pop(),
            );
          }
          return _RecordingView(
            state: state,
            exerciseContent: exerciseContent,
            exerciseType: exerciseType,
            exerciseId: exerciseId,
          );
        },
      ),
    );
  }
}

// ── Recording view ────────────────────────────────────────────────
class _RecordingView extends StatelessWidget {
  final PronunciationState state;
  final String exerciseContent;
  final String exerciseType;
  final int exerciseId;

  const _RecordingView({
    required this.state,
    required this.exerciseContent,
    required this.exerciseType,
    required this.exerciseId,
  });

  bool get _isRecording => state is PronunciationRecording;
  bool get _isCountdown => state is PronunciationCountdown;
  bool get _isScoring => state is PronunciationScoring;
  bool get _isPlayingRef => state is PronunciationPlayingReference;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),

          // ── Exercise content card ─────────────────────────────
          PaperCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Text(
                  _labelForType(exerciseType),
                  style: AppTextStyles.label.copyWith(color: AppColors.leaf),
                ),
                const SizedBox(height: AppSpacing.md),
                // The words the child has to decode. Set in readingText —
                // canonical letterforms, generous tracking — not the
                // handwriting face: this is the thing being taught, not
                // decoration.
                Text(
                  exerciseContent,
                  style: AppTextStyles.readingText,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),

          const SizedBox(height: AppSpacing.lg),

          // ── Reference audio button ────────────────────────────
          if (!_isRecording && !_isCountdown && !_isScoring)
            _ReferenceAudioButton(
              exerciseId: exerciseId,
              isPlaying: _isPlayingRef,
            ).animate(delay: 100.ms).fadeIn(duration: 350.ms),

          const SizedBox(height: AppSpacing.xl),

          // ── State-dependent centre ────────────────────────────
          if (_isCountdown)
            CountdownDisplay(
              count: (state as PronunciationCountdown).count,
            )
          else if (_isRecording)
            _RecordingIndicator(
              elapsed: (state as PronunciationRecording).elapsed,
            )
          else if (_isScoring)
            _ScoringIndicator()
          else if (_isPlayingRef)
            _PlayingIndicator()
          else
            _IdleInstructions(),

          const SizedBox(height: AppSpacing.xxl),

          // ── Mic button ────────────────────────────────────────
          MicButton(
            isRecording: _isRecording,
            isDisabled: _isCountdown || _isScoring || _isPlayingRef,
            onTap: () {
              if (_isRecording) {
                context.read<PronunciationCubit>().stopAndSubmit(exerciseId);
              } else {
                context.read<PronunciationCubit>().startRecording();
              }
            },
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            _isRecording
                ? 'Tap to stop'
                : _isCountdown
                    ? 'Starting...'
                    : _isScoring
                        ? 'Scoring...'
                        : 'Tap to speak',
            style: AppTextStyles.bodyMedium.copyWith(
              color: _isRecording ? AppColors.coral : AppColors.textSecondary,
              fontWeight: _isRecording ? FontWeight.w700 : FontWeight.w400,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          if (!_isRecording && !_isCountdown && !_isScoring)
            _TipCard().animate(delay: 300.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  String _labelForType(String type) {
    switch (type) {
      case 'WORD':
        return 'SAY THIS WORD';
      case 'SENTENCE':
        return 'READ THIS SENTENCE';
      case 'PARAGRAPH':
        return 'READ THIS PARAGRAPH';
      case 'PHONEME':
        return 'SAY THIS SOUND';
      default:
        return 'SAY THIS';
    }
  }
}

// ── Reference audio button ────────────────────────────────────────
class _ReferenceAudioButton extends StatelessWidget {
  final int exerciseId;
  final bool isPlaying;

  const _ReferenceAudioButton({
    required this.exerciseId,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isPlaying
          ? null
          : () => context.read<PronunciationCubit>().playReference(exerciseId),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.sm + 4,
        ),
        decoration: BoxDecoration(
          color: AppColors.leafLight,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.leaf,
            width: AppBorders.standard,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying ? Icons.graphic_eq_rounded : Icons.hearing_rounded,
              color: AppColors.leafDark,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              isPlaying ? 'Playing...' : 'Hear the example',
              style: AppTextStyles.buttonMedium.copyWith(
                color: AppColors.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scored view ───────────────────────────────────────────────────
class _ScoredView extends StatelessWidget {
  final PronunciationScored state;
  final String exerciseContent;
  final VoidCallback onTryAgain;
  final VoidCallback onNext;

  const _ScoredView({
    required this.state,
    required this.exerciseContent,
    required this.onTryAgain,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        children: [
          // The prompt is repeated above the result so the child can see
          // the words they read while looking at the breakdown. Set in the
          // reading style, not the handwriting face: this is decodable
          // text, not decoration.
          Text(
            exerciseContent,
            style: AppTextStyles.headingSmall.copyWith(
              color: AppColors.inkSoft,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: AppSpacing.xl),
          ScoreResultCard(
            state: state,
            expectedText: exerciseContent,
            onTryAgain: onTryAgain,
            onNext: onNext,
          ),
        ],
      ),
    );
  }
}

// ── Small state widgets ───────────────────────────────────────────
class _RecordingIndicator extends StatelessWidget {
  final Duration elapsed;
  const _RecordingIndicator({required this.elapsed});

  @override
  Widget build(BuildContext context) {
    final s = elapsed.inSeconds;
    final ms = (elapsed.inMilliseconds % 1000) ~/ 100;
    return Column(
      children: [
        const RecordingWaveform(),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.coral,
                shape: BoxShape.circle,
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .fadeOut(duration: 500.ms)
                .then()
                .fadeIn(duration: 500.ms),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '0:0$s.$ms',
              style: AppTextStyles.headingMedium
                  .copyWith(color: AppColors.coral, fontFamily: 'Nunito'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text('Max 10 seconds', style: AppTextStyles.bodySmall),
      ],
    );
  }
}

class _ScoringIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.teal),
          strokeWidth: 3,
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('Analysing your pronunciation...', style: AppTextStyles.bodyMedium)
            .animate(onPlay: (c) => c.repeat())
            .fadeOut(duration: 800.ms)
            .then()
            .fadeIn(duration: 800.ms),
      ],
    );
  }
}

class _PlayingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(Icons.hearing_rounded, color: AppColors.teal, size: 48),
        SizedBox(height: AppSpacing.md),
        Text('Listen carefully...', style: AppTextStyles.bodyMedium),
      ],
    );
  }
}

class _IdleInstructions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Kiki(size: 90).animate().fadeIn(duration: 400.ms).scale(
              begin: const Offset(0.8, 0.8),
              duration: 500.ms,
              curve: Curves.elasticOut,
            ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Ready to practise?',
          style: AppTextStyles.headingSmall,
          textAlign: TextAlign.center,
        ).animate(delay: 200.ms).fadeIn(duration: 300.ms),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.honeyLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.honey,
          width: AppBorders.hairline,
        ),
      ),
      child: const Row(
        children: [
          Text('💡', style: TextStyle(fontSize: 20)),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Listen to the example first, then record yourself!',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
