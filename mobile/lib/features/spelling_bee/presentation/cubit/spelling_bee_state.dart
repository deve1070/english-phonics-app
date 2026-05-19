import 'package:equatable/equatable.dart';

enum SpellingBeeDifficulty { easy, medium, hard }

extension SpellingBeeDifficultyX on SpellingBeeDifficulty {
  String get label {
    switch (this) {
      case SpellingBeeDifficulty.easy:
        return 'Easy 🌱';
      case SpellingBeeDifficulty.medium:
        return 'Medium 🚀';
      case SpellingBeeDifficulty.hard:
        return 'Hard 🏆';
    }
  }

  String get emoji {
    switch (this) {
      case SpellingBeeDifficulty.easy:
        return '🌱';
      case SpellingBeeDifficulty.medium:
        return '🚀';
      case SpellingBeeDifficulty.hard:
        return '🏆';
    }
  }
}

abstract class SpellingBeeState extends Equatable {
  const SpellingBeeState();
  @override
  List<Object?> get props => [];
}

class SpellingBeeInitial extends SpellingBeeState {
  const SpellingBeeInitial();
}

class SpellingBeeLoading extends SpellingBeeState {
  const SpellingBeeLoading();
}

class SpellingBeeReady extends SpellingBeeState {
  final String word;
  final List<String> shuffledLetters;
  final List<String?> placedLetters;
  final bool hasPlayedAudio;
  final int score;
  final int round;
  final int totalRounds;
  final SpellingBeeDifficulty difficulty;

  const SpellingBeeReady({
    required this.word,
    required this.shuffledLetters,
    required this.placedLetters,
    required this.hasPlayedAudio,
    required this.score,
    required this.round,
    required this.totalRounds,
    required this.difficulty,
  });

  bool get isComplete => placedLetters.every((l) => l != null);
  bool get isCorrect =>
      placedLetters.join('').toLowerCase() == word.toLowerCase();
  int get filledCount => placedLetters.where((l) => l != null).length;

  SpellingBeeReady copyWith({
    List<String?>? placedLetters,
    bool? hasPlayedAudio,
    int? score,
  }) =>
      SpellingBeeReady(
        word: word,
        shuffledLetters: shuffledLetters,
        placedLetters: placedLetters ?? this.placedLetters,
        hasPlayedAudio: hasPlayedAudio ?? this.hasPlayedAudio,
        score: score ?? this.score,
        round: round,
        totalRounds: totalRounds,
        difficulty: difficulty,
      );

  @override
  List<Object?> get props =>
      [word, placedLetters, hasPlayedAudio, score, round, difficulty];
}

class SpellingBeeResult extends SpellingBeeState {
  final String word;
  final bool isCorrect;
  final int score;
  final int round;
  final int totalRounds;
  final bool isFinalRound;
  final SpellingBeeDifficulty difficulty;
  final bool wasCorrect;

  const SpellingBeeResult({
    required this.word,
    required this.isCorrect,
    required this.score,
    required this.round,
    required this.totalRounds,
    required this.difficulty,
    required this.wasCorrect,
  }) : isFinalRound = round >= totalRounds;

  @override
  List<Object?> get props => [word, isCorrect, score, round, difficulty];
}

class SpellingBeeDone extends SpellingBeeState {
  final int finalScore;
  final int totalRounds;

  const SpellingBeeDone({
    required this.finalScore,
    required this.totalRounds,
  });

  double get percentage => finalScore / totalRounds;

  String get grade {
    if (percentage >= 0.9) return 'Champion! 🏆';
    if (percentage >= 0.7) return 'Great job! ⭐';
    if (percentage >= 0.5) return 'Good try! 👍';
    return 'Keep practising! 💪';
  }

  @override
  List<Object?> get props => [finalScore, totalRounds];
}

class SpellingBeeError extends SpellingBeeState {
  final String message;
  const SpellingBeeError(this.message);
  @override
  List<Object?> get props => [message];
}
