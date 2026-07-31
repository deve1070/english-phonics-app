import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';

abstract class PronunciationState extends Equatable {
  const PronunciationState();
  @override
  List<Object?> get props => [];
}

class PronunciationInitial extends PronunciationState {
  const PronunciationInitial();
}

/// Playback of the reference audio
class PronunciationPlayingReference extends PronunciationState {
  const PronunciationPlayingReference();
}

/// Countdown before recording starts (3-2-1)
class PronunciationCountdown extends PronunciationState {
  final int count;
  const PronunciationCountdown(this.count);
  @override
  List<Object?> get props => [count];
}

/// Actively recording the kid's voice
class PronunciationRecording extends PronunciationState {
  final Duration elapsed;
  const PronunciationRecording({this.elapsed = Duration.zero});
  @override
  List<Object?> get props => [elapsed];
}

/// Uploading audio + waiting for backend score
class PronunciationScoring extends PronunciationState {
  const PronunciationScoring();
}

/// Score received
class PronunciationScored extends PronunciationState {
  final double score;
  final int exerciseId;
  final bool isCompleted; // score >= 80

  /// What the recognizer heard, used to show per-word feedback.
  final String heardText;

  /// Best score across attempts at this exercise in this sitting.
  ///
  /// The server already keeps the best score permanently (Progress upserts
  /// with greatest()), so a retry can only ever help. Surfacing the best
  /// makes that visible: it turns a repeat attempt from "I failed, do it
  /// again" into "beat your record", which is the whole reason retries are
  /// free.
  final double bestScore;

  /// True when this attempt beat everything before it in this sitting.
  final bool isPersonalBest;

  const PronunciationScored({
    required this.score,
    required this.exerciseId,
    required this.isCompleted,
    this.heardText = '',
    double? bestScore,
    this.isPersonalBest = false,
  }) : bestScore = bestScore ?? score;

  /// Encouragement, never a verdict.
  ///
  /// Nothing here names failure. The lowest band still points forward,
  /// because the child has to want to press the button again — that is the
  /// only thing that actually improves their reading.
  String get grade {
    if (score >= ScoreThresholds.perfect) return 'Perfect!';
    if (score >= ScoreThresholds.good) return 'Brilliant!';
    if (score >= ScoreThresholds.pass) return 'You did it!';
    if (score >= 55) return 'So close!';
    return 'Good try!';
  }

  @override
  List<Object?> get props =>
      [score, exerciseId, isCompleted, heardText, bestScore, isPersonalBest];
}

class PronunciationError extends PronunciationState {
  final String message;
  const PronunciationError(this.message);
  @override
  List<Object?> get props => [message];
}
