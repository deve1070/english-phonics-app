import 'package:equatable/equatable.dart';

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

  const PronunciationScored({
    required this.score,
    required this.exerciseId,
    required this.isCompleted,
  });

  String get grade {
    if (score >= 98) return 'Perfect!';
    if (score >= 90) return 'Excellent!';
    if (score >= 80) return 'Great job!';
    if (score >= 60) return 'Keep trying!';
    return 'Try again!';
  }

  String get mascotAsset {
    if (score >= 80) return 'assets/images/popiE.png'; // excited
    return 'assets/images/popi.png'; // normal
  }

  @override
  List<Object?> get props => [score, exerciseId, isCompleted];
}

class PronunciationError extends PronunciationState {
  final String message;
  const PronunciationError(this.message);
  @override
  List<Object?> get props => [message];
}
