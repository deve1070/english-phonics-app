import '../../domain/entities/lesson_entity.dart';

class PhonemeModel extends PhonemeEntity {
  const PhonemeModel({
    required super.id,
    required super.symbol,
    super.graphemes,
    required super.description,
    super.audioUrl,
    required super.type,
    required super.order,
  });

  factory PhonemeModel.fromJson(Map<String, dynamic> json) => PhonemeModel(
        id: json['id'] as int,
        symbol: json['symbol'] as String,
        // Left null when absent rather than defaulted to the symbol: the
        // letters a child is shown come from here, and a symbol is not a
        // spelling.
        graphemes: json['graphemes'] as String?,
        description: json['description'] as String? ?? '',
        audioUrl: json['audio_url'] as String?,
        // FIX: type comes as lowercase from backend enum e.g. "ALPHABET"
        type: json['type'] as String? ?? 'ALPHABET',
        order: json['order'] as int? ?? 0,
      );
}

class LessonModel extends LessonEntity {
  const LessonModel({
    required super.id,
    required super.order,
    required super.level,
    required super.phonemes,
    required super.totalExercises,
    required super.completedExercises,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) {
    // FIX: backend returns 'exercise_count' on detail endpoint,
    // not 'total_exercises'/'completed_exercises'.
    // completedExercises stays 0 until progress endpoint is wired.
    final exerciseCount = (json['exercise_count'] as int?) ??
        (json['total_exercises'] as int?) ??
        0;

    return LessonModel(
      id: json['id'] as int,
      order: json['order'] as int? ?? 0,
      level: json['level'] as String? ?? 'LEVEL1',
      phonemes: (json['phonemes'] as List<dynamic>? ?? [])
          .map((p) => PhonemeModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      totalExercises: exerciseCount,
      // completedExercises will be filled in when progress endpoint
      // is added in a later phase
      completedExercises: json['completed_exercises'] as int? ?? 0,
    );
  }
}
