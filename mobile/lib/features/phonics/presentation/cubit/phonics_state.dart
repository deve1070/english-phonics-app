import 'package:equatable/equatable.dart';
import '../../domain/entities/lesson_entity.dart';
import '../../domain/entities/exercise_entity.dart';

abstract class PhonicsState extends Equatable {
  const PhonicsState();
  @override
  List<Object?> get props => [];
}

class PhonicsInitial extends PhonicsState {
  const PhonicsInitial();
}

class PhonicsLoading extends PhonicsState {
  const PhonicsLoading();
}

class PhonicsLoaded extends PhonicsState {
  final LessonEntity lesson;
  final List<ExerciseEntity> exercises;
  final int currentPhonemeIndex;
  final bool isPlayingAudio;

  // ── Pronunciation gate ──────────────────────────────────────
  // true = student has scored at or above the gate pass threshold
  // false = student must pass the pronunciation check first
  final bool phonemeUnlocked;

  // Score from the most recent pronunciation attempt on this phoneme
  final double? lastGateScore;

  // Whether the gate recording/submission is in progress
  final bool isGateRecording;
  final bool isGateScoring;

  // Whether AI exercise generation is in progress
  final bool isGeneratingExercises;

  const PhonicsLoaded({
    required this.lesson,
    required this.exercises,
    this.currentPhonemeIndex = 0,
    this.isPlayingAudio = false,
    this.phonemeUnlocked = false,
    this.lastGateScore,
    this.isGateRecording = false,
    this.isGateScoring = false,
    this.isGeneratingExercises = false,
  });

  PhonemeEntity? get currentPhoneme =>
      lesson.phonemes.isNotEmpty ? lesson.phonemes[currentPhonemeIndex] : null;

  bool get isLastPhoneme => currentPhonemeIndex >= lesson.phonemes.length - 1;

  bool get isFirstPhoneme => currentPhonemeIndex == 0;

  /// Pass threshold — kept low for easier testing.
  static const double gatePassScore = 20.0;

  PhonicsLoaded copyWith({
    int? currentPhonemeIndex,
    bool? isPlayingAudio,
    bool? phonemeUnlocked,
    double? lastGateScore,
    bool? isGateRecording,
    bool? isGateScoring,
    bool? isGeneratingExercises,
    List<ExerciseEntity>? exercises,
  }) =>
      PhonicsLoaded(
        lesson: lesson,
        exercises: exercises ?? this.exercises,
        currentPhonemeIndex: currentPhonemeIndex ?? this.currentPhonemeIndex,
        isPlayingAudio: isPlayingAudio ?? this.isPlayingAudio,
        phonemeUnlocked: phonemeUnlocked ?? this.phonemeUnlocked,
        lastGateScore: lastGateScore ?? this.lastGateScore,
        isGateRecording: isGateRecording ?? this.isGateRecording,
        isGateScoring: isGateScoring ?? this.isGateScoring,
        isGeneratingExercises:
            isGeneratingExercises ?? this.isGeneratingExercises,
      );

  @override
  List<Object?> get props => [
        lesson,
        exercises,
        currentPhonemeIndex,
        isPlayingAudio,
        phonemeUnlocked,
        lastGateScore,
        isGateRecording,
        isGateScoring,
        isGeneratingExercises,
      ];
}

class PhonicsError extends PhonicsState {
  final String message;
  const PhonicsError(this.message);
  @override
  List<Object?> get props => [message];
}
