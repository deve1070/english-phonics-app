import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../cubit/pronunciation_cubit.dart';
import '../cubit/pronunciation_state.dart';
import '../widgets/mic_button.dart';
import '../widgets/score_result_card.dart';

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
        title: Text('Pronunciation', style: AppTextStyles.headingSmall),
        centerTitle: true,
      ),
      body: BlocBuilder<PronunciationCubit, PronunciationState>(
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8FAF8), Color(0xFFF0FFF9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: AppColors.teal.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Text(
                  _labelForType(exerciseType),
                  style: AppTextStyles.label.copyWith(color: AppColors.teal),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  exerciseContent,
                  style: AppTextStyles.displaySmall.copyWith(
                    fontFamily: 'PatrickHand',
                    fontSize: 36,
                    color: AppColors.textPrimary,
                  ),
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
          color: AppColors.teal.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: AppColors.teal.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying ? Icons.graphic_eq_rounded : Icons.hearing_rounded,
              color: AppColors.teal,
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
        Text('Max 10 seconds', style: AppTextStyles.bodySmall),
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
        Text('Analysing your pronunciation...', style: AppTextStyles.bodyMedium)
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
    return Column(
      children: [
        const Icon(Icons.hearing_rounded, color: AppColors.teal, size: 48),
        const SizedBox(height: AppSpacing.md),
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
        Image.asset(
          'assets/images/popi.png',
          height: 90,
          errorBuilder: (_, __, ___) =>
              const Text('🎤', style: TextStyle(fontSize: 64)),
        ).animate().fadeIn(duration: 400.ms).scale(
              begin: const Offset(0.8, 0.8),
              duration: 500.ms,
              curve: Curves.elasticOut,
            ),
        const SizedBox(height: AppSpacing.md),
        Text(
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
        color: AppColors.yellow.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.yellow.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: AppSpacing.sm),
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
