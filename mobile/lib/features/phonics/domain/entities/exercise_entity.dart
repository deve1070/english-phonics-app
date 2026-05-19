class ExerciseEntity {
  final int id;
  final int lessonId;
  final String content;
  final String type; // WORD, SENTENCE, PHONEME, PARAGRAPH
  final int difficulty;

  const ExerciseEntity({
    required this.id,
    required this.lessonId,
    required this.content,
    required this.type,
    required this.difficulty,
  });
}
