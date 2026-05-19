import 'package:equatable/equatable.dart';
import '../../../phonics/domain/entities/lesson_entity.dart';

abstract class ProgressState extends Equatable {
  const ProgressState();
  @override
  List<Object?> get props => [];
}

class ProgressInitial extends ProgressState {
  const ProgressInitial();
}

class ProgressLoading extends ProgressState {
  const ProgressLoading();
}

class ProgressLoaded extends ProgressState {
  final List<LessonEntity> lessons;

  final int streakDays;
  // NEW: motivational feedback from GET /progress/me/feedback
  final String feedbackMessage;
  final double? averageRecentScore;
  final int practicedCount;

  const ProgressLoaded({
    required this.lessons,
    required this.streakDays,
    this.feedbackMessage = 'Start practising to get personalised feedback!',
    this.averageRecentScore,
    this.practicedCount = 0,
  });

  int get completedLessons => lessons.where((l) => l.isCompleted).length;
  int get totalLessons => lessons.length;

  int get completedExercises =>
      lessons.fold(0, (s, l) => s + l.completedExercises);
  int get totalExercises => lessons.fold(0, (s, l) => s + l.totalExercises);

  double get overallProgress =>
      totalExercises == 0 ? 0 : completedExercises / totalExercises;

  @override
  List<Object?> get props =>
      [lessons, streakDays, feedbackMessage, practicedCount];
}

class ProgressError extends ProgressState {
  final String message;
  const ProgressError(this.message);
  @override
  List<Object?> get props => [message];
}
