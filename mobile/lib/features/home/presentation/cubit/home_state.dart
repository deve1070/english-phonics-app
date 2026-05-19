import 'package:equatable/equatable.dart';
import '../../../phonics/domain/entities/lesson_entity.dart';
import '../../../auth/domain/entities/user_entity.dart';

abstract class HomeState extends Equatable {
  const HomeState();
  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {
  const HomeInitial();
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeLoaded extends HomeState {
  final UserEntity user;
  final List<LessonEntity> lessons;
  final int streakDays;

  const HomeLoaded({
    required this.user,
    required this.lessons,
    required this.streakDays,
  });

  int get totalCompleted => lessons.where((l) => l.isCompleted).length;

  double get overallProgress {
    if (lessons.isEmpty) return 0;
    final totalEx = lessons.fold(0, (s, l) => s + l.totalExercises);
    final doneEx = lessons.fold(0, (s, l) => s + l.completedExercises);
    return totalEx == 0 ? 0 : doneEx / totalEx;
  }

  LessonEntity? get nextLesson =>
      lessons.where((l) => !l.isCompleted).isNotEmpty
          ? lessons.firstWhere((l) => !l.isCompleted)
          : null;

  @override
  List<Object?> get props => [user, lessons, streakDays];
}

class HomeError extends HomeState {
  final String message;
  const HomeError(this.message);
  @override
  List<Object?> get props => [message];
}
