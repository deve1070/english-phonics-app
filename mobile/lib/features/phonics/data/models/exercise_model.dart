import '../../domain/entities/exercise_entity.dart';

class ExerciseModel extends ExerciseEntity {
  const ExerciseModel({
    required super.id,
    required super.lessonId,
    required super.content,
    required super.type,
    required super.difficulty,
  });

  factory ExerciseModel.fromJson(Map<String, dynamic> json) => ExerciseModel(
        id: json['id'] as int,
        lessonId: json['lesson_id'] as int? ?? 0,
        content: json['content'] as String,
        type: json['type'] as String? ?? 'WORD',
        difficulty: json['difficulty'] as int? ?? 1,
      );
}
