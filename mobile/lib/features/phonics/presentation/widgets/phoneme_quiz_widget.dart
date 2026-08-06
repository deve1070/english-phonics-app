import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/entities/lesson_entity.dart';

/// Two modes of multiple-choice phoneme identification:
///
/// [PhonemeQuizMode.hearThenPick]
///   Student hears a phoneme sound → picks the correct symbol from 4 options.
///   "Which sound did you hear?"
///
/// [PhonemeQuizMode.seeThenPick]
///   Student sees a phoneme symbol → picks the correct sound button from 4.
///   "Which sound does this symbol make?"
enum PhonemeQuizMode { hearThenPick, seeThenPick }

/// A single multiple-choice question for phoneme identification.
class PhonemeQuizCard extends StatefulWidget {
  /// The correct phoneme
  final PhonemeEntity correctPhoneme;

  /// All 4 options (includes the correct one, already shuffled)
  final List<PhonemeEntity> options;

  /// Quiz mode
  final PhonemeQuizMode mode;

  /// Called with the selected phoneme when student taps an option.
  /// Parent should compare selected.id == correctPhoneme.id to check.
  final void Function(PhonemeEntity selected) onAnswer;

  /// Called when student taps the speaker button to hear the sound.
  final void Function(int phonemeId) onPlaySound;

  /// Whether audio is currently playing
  final bool isPlayingAudio;

  const PhonemeQuizCard({
    super.key,
    required this.correctPhoneme,
    required this.options,
    required this.mode,
    required this.onAnswer,
    required this.onPlaySound,
    required this.isPlayingAudio,
  });

  @override
  State<PhonemeQuizCard> createState() => _PhonemeQuizCardState();
}

class _PhonemeQuizCardState extends State<PhonemeQuizCard> {
  PhonemeEntity? _selected;
  bool get _answered => _selected != null;
  bool _heardSound = false;

  void _handleTap(PhonemeEntity option) {
    if (_answered) return;
    if (!_heardSound) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap "Hear the sound" first!'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _selected = option);
    widget.onAnswer(option);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Question prompt ───────────────────────────────────
        _QuestionPrompt(
          mode: widget.mode,
          correctPhoneme: widget.correctPhoneme,
          isPlayingAudio: widget.isPlayingAudio,
          onPlaySound: widget.onPlaySound,
          onHeardSound: () => setState(() => _heardSound = true),
        ).animate().fadeIn(duration: 400.ms),

        const SizedBox(height: AppSpacing.xl),

        // ── 4 answer options in 2×2 grid ──────────────────────
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.6,
          children: widget.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            return _OptionTile(
              option: option,
              mode: widget.mode,
              selected: _selected,
              correctPhoneme: widget.correctPhoneme,
              answered: _answered,
              animationIndex: index,
              onTap: () => _handleTap(option),
              onPlaySound: widget.onPlaySound,
              isPlayingAudio: widget.isPlayingAudio,
            );
          }).toList(),
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── Result feedback ───────────────────────────────────
        if (_answered)
          _ResultBanner(
            isCorrect: _selected!.id == widget.correctPhoneme.id,
            correctSymbol: widget.correctPhoneme.symbol,
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.3, end: 0),
      ],
    );
  }
}

// ── Question prompt ───────────────────────────────────────────────
class _QuestionPrompt extends StatelessWidget {
  final PhonemeQuizMode mode;
  final PhonemeEntity correctPhoneme;
  final bool isPlayingAudio;
  final void Function(int) onPlaySound;
  final VoidCallback onHeardSound;

  const _QuestionPrompt({
    required this.mode,
    required this.correctPhoneme,
    required this.isPlayingAudio,
    required this.onPlaySound,
    required this.onHeardSound,
  });

  @override
  Widget build(BuildContext context) {
    if (mode == PhonemeQuizMode.hearThenPick) {
      // Show speaker button — student hears then picks symbol
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                  color: AppColors.teal.withOpacity(0.3), width: 1.5),
            ),
            child: Text(
              '👂 Which sound did you hear?',
              style: AppTextStyles.headingSmall.copyWith(color: AppColors.teal),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _PlaySoundButton(
            phonemeId: correctPhoneme.id,
            isPlaying: isPlayingAudio,
            onTap: (id) {
              onHeardSound();
              onPlaySound(id);
            },
          ),
        ],
      );
    } else {
      // Show phoneme symbol — student picks the correct sound
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.coral.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                  color: AppColors.coral.withOpacity(0.3), width: 1.5),
            ),
            child: Text(
              '🔊 Which sound does this make?',
              style:
                  AppTextStyles.headingSmall.copyWith(color: AppColors.coral),
              textAlign: TextAlign.center,
            ),
          ),
          // The spellings, small and capital. Read from the curriculum's
          // graphemes, never from its symbol.
          Text(
            correctPhoneme.letters,
            style: AppTextStyles.phonemeDisplay.copyWith(
              fontSize: correctPhoneme.letters.length > 8
                  ? 36
                  : (correctPhoneme.letters.length > 4 ? 48 : 64),
              color: AppColors.coral,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
  }
}

// ── Play sound button ─────────────────────────────────────────────
class _PlaySoundButton extends StatelessWidget {
  final int phonemeId;
  final bool isPlaying;
  final void Function(int) onTap;

  const _PlaySoundButton({
    required this.phonemeId,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isPlaying ? null : () => onTap(phonemeId),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.teal, Color(0xFF38B2A9)],
          ),
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: [
            BoxShadow(
              color: AppColors.teal.withOpacity(0.4),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              isPlaying ? 'Playing...' : 'Hear the sound',
              style: AppTextStyles.buttonLarge,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Option tile ───────────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final PhonemeEntity option;
  final PhonemeQuizMode mode;
  final PhonemeEntity? selected;
  final PhonemeEntity correctPhoneme;
  final bool answered;
  final int animationIndex;
  final VoidCallback onTap;
  final void Function(int) onPlaySound;
  final bool isPlayingAudio;

  const _OptionTile({
    required this.option,
    required this.mode,
    required this.selected,
    required this.correctPhoneme,
    required this.answered,
    required this.animationIndex,
    required this.onTap,
    required this.onPlaySound,
    required this.isPlayingAudio,
  });

  bool get _isCorrect => option.id == correctPhoneme.id;
  bool get _isSelected => selected?.id == option.id;

  Color _bgColor() {
    if (!answered) return AppColors.surface;
    if (_isCorrect) return AppColors.green.withOpacity(0.15);
    if (_isSelected) return AppColors.coral.withOpacity(0.15);
    return AppColors.surface;
  }

  Color _borderColor() {
    if (!answered) return AppColors.border;
    if (_isCorrect) return AppColors.green;
    if (_isSelected) return AppColors.coral;
    return AppColors.border;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: answered ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: _bgColor(),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: _borderColor(),
            width: answered && (_isCorrect || _isSelected) ? 2.5 : 1.5,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Stack(
          children: [
            Center(
              child: mode == PhonemeQuizMode.hearThenPick
                  // hearThenPick options show symbols
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          option.letters,
                          style: AppTextStyles.phonemeDisplay.copyWith(
                            fontSize: option.letters.length > 8
                                ? 16
                                : (option.letters.length > 4 ? 20 : 26),
                            color: answered && _isCorrect
                                ? AppColors.green
                                : AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  // seeThenPick options show speaker buttons
                  : _SoundOptionButton(
                      option: option,
                      isPlaying: isPlayingAudio,
                      onTap: onPlaySound,
                      answered: answered,
                      isCorrect: _isCorrect,
                    ),
            ),
            // Correct / wrong indicator
            if (answered && (_isCorrect || _isSelected))
              Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  _isCorrect
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: _isCorrect ? AppColors.green : AppColors.coral,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: animationIndex * 80))
        .fadeIn(duration: 300.ms)
        .scale(begin: const Offset(0.9, 0.9), duration: 300.ms);
  }
}

// ── Sound option button (for seeThenPick mode) ────────────────────
class _SoundOptionButton extends StatelessWidget {
  final PhonemeEntity option;
  final bool isPlaying;
  final void Function(int) onTap;
  final bool answered;
  final bool isCorrect;

  const _SoundOptionButton({
    required this.option,
    required this.isPlaying,
    required this.onTap,
    required this.answered,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final color = answered && isCorrect ? AppColors.green : AppColors.teal;
    return GestureDetector(
      onTap: () => onTap(option.id),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.volume_up_rounded, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            'Sound ${option.order}',
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Result banner ─────────────────────────────────────────────────
class _ResultBanner extends StatelessWidget {
  final bool isCorrect;
  final String correctSymbol;

  const _ResultBanner({
    required this.isCorrect,
    required this.correctSymbol,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: isCorrect
            ? AppColors.green.withOpacity(0.12)
            : AppColors.coral.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isCorrect
              ? AppColors.green.withOpacity(0.4)
              : AppColors.coral.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Text(
            isCorrect ? '🎉' : '💡',
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              isCorrect
                  ? 'Correct! Great job!'
                  : 'Not quite — the answer was /$correctSymbol/',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isCorrect ? AppColors.green : AppColors.coral,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quiz session widget ───────────────────────────────────────────
/// Manages a sequence of quiz questions for all learned phonemes.
/// Shows [PhonemeQuizCard]s one at a time, alternating between modes.
class PhonemeQuizSession extends StatefulWidget {
  /// All phonemes the student has learned (order <= current phoneme order)
  final List<PhonemeEntity> learnedPhonemes;

  /// The current phoneme being studied
  final PhonemeEntity currentPhoneme;

  /// Called when all questions in the session are done
  final VoidCallback onComplete;

  final void Function(int phonemeId) onPlaySound;
  final bool isPlayingAudio;

  /// Number of quiz questions to show (default 4)
  final int questionCount;

  const PhonemeQuizSession({
    super.key,
    required this.learnedPhonemes,
    required this.currentPhoneme,
    required this.onComplete,
    required this.onPlaySound,
    required this.isPlayingAudio,
    this.questionCount = 4,
  });

  @override
  State<PhonemeQuizSession> createState() => _PhonemeQuizSessionState();
}

class _PhonemeQuizSessionState extends State<PhonemeQuizSession> {
  final Random _random = Random();
  late List<_QuizQuestion> _questions;
  int _currentIndex = 0;
  int _correctCount = 0;
  bool _currentAnswered = false;

  @override
  void initState() {
    super.initState();
    _questions = _buildQuestions();
  }

  List<_QuizQuestion> _buildQuestions() {
    final phonemes = widget.learnedPhonemes;
    if (phonemes.isEmpty) return [];

    final questions = <_QuizQuestion>[];
    final count = widget.questionCount.clamp(1, phonemes.length);

    // Always include the current phoneme as correct answer at least once
    final shuffled = [...phonemes]..shuffle(_random);

    for (int i = 0; i < count; i++) {
      // Alternate between modes
      final mode =
          i.isEven ? PhonemeQuizMode.hearThenPick : PhonemeQuizMode.seeThenPick;

      // Pick correct phoneme — first question always uses the current phoneme
      final correct =
          i == 0 ? widget.currentPhoneme : shuffled[i % shuffled.length];

      // Pick 3 wrong options from remaining phonemes
      final wrong = phonemes.where((p) => p.id != correct.id).toList()
        ..shuffle(_random);
      final options = [correct, ...wrong.take(3)]..shuffle(_random);

      questions.add(_QuizQuestion(
        correct: correct,
        options: options,
        mode: mode,
      ));
    }

    return questions;
  }

  void _handleAnswer(PhonemeEntity selected) {
    if (_currentAnswered) return;
    setState(() {
      _currentAnswered = true;
      if (selected.id == _questions[_currentIndex].correct.id) {
        _correctCount++;
      }
    });
  }

  void _next() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _currentAnswered = false;
      });
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      // Not enough phonemes for a quiz yet — skip straight to exercises
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onComplete());
      return const SizedBox();
    }

    final q = _questions[_currentIndex];
    final isLast = _currentIndex == _questions.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress indicator
        _QuizProgress(
          current: _currentIndex + 1,
          total: _questions.length,
          correct: _correctCount,
        ),

        const SizedBox(height: AppSpacing.lg),

        PhonemeQuizCard(
          key: ValueKey(_currentIndex),
          correctPhoneme: q.correct,
          options: q.options,
          mode: q.mode,
          onAnswer: _handleAnswer,
          onPlaySound: widget.onPlaySound,
          isPlayingAudio: widget.isPlayingAudio,
        ),

        const SizedBox(height: AppSpacing.lg),

        // Next / Finish button — only visible after answering
        if (_currentAnswered)
          SizedBox(
            width: double.infinity,
            height: AppSizes.minTouchTarget,
            child: ElevatedButton.icon(
              onPressed: _next,
              icon: Icon(
                isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                size: 20,
              ),
              label: Text(isLast ? 'See Exercises 🎯' : 'Next Question'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                elevation: 0,
              ),
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0),
      ],
    );
  }
}

class _QuizQuestion {
  final PhonemeEntity correct;
  final List<PhonemeEntity> options;
  final PhonemeQuizMode mode;
  _QuizQuestion({
    required this.correct,
    required this.options,
    required this.mode,
  });
}

// ── Quiz progress bar ─────────────────────────────────────────────
class _QuizProgress extends StatelessWidget {
  final int current;
  final int total;
  final int correct;

  const _QuizProgress({
    required this.current,
    required this.total,
    required this.correct,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question $current of $total',
                style: AppTextStyles.label,
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  value: current / total,
                  backgroundColor: AppColors.teal.withOpacity(0.12),
                  valueColor: const AlwaysStoppedAnimation(AppColors.teal),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.green.withOpacity(0.12),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            '✅ $correct',
            style: AppTextStyles.label.copyWith(color: AppColors.green),
          ),
        ),
      ],
    );
  }
}
