class LessonEntity {
  final int id;
  final int order;
  final String level;
  final List<PhonemeEntity> phonemes;
  final int totalExercises;
  final int completedExercises;

  const LessonEntity({
    required this.id,
    required this.order,
    required this.level,
    required this.phonemes,
    required this.totalExercises,
    required this.completedExercises,
  });

  double get progressPercent =>
      totalExercises == 0 ? 0 : completedExercises / totalExercises;

  bool get isCompleted =>
      completedExercises >= totalExercises && totalExercises > 0;
  bool get isStarted => completedExercises > 0;
}

class PhonemeEntity {
  final int id;
  final String symbol;
  final String description;
  final String? audioUrl;
  final String type;
  final int order;

  const PhonemeEntity({
    required this.id,
    required this.symbol,
    required this.description,
    this.audioUrl,
    required this.type,
    required this.order,
  });
}
