import 'package:dio/dio.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/lesson_model.dart';

class LessonsRemoteDataSource {
  final Dio _dio;
  LessonsRemoteDataSource(this._dio);

  Future<List<LessonModel>> getLessons() async {
    final response = await _dio.get(ApiConstants.lessons);
    final list = response.data as List<dynamic>;
    final lessons = list
        .map((e) => LessonModel.fromJson(e as Map<String, dynamic>))
        .toList();
    // Sort by lesson order so home screen shows them in correct sequence
    lessons.sort((a, b) => a.order.compareTo(b.order));
    return lessons;
  }

  Future<LessonModel> getLessonById(int id) async {
    final response = await _dio.get(ApiConstants.lessonById(id));
    final lesson = LessonModel.fromJson(response.data as Map<String, dynamic>);
    // Phonemes already sorted by order in backend response (sorted in endpoint)
    // but sort defensively here too so Flutter never shows wrong order
    final sortedPhonemes = [...lesson.phonemes]
      ..sort((a, b) => a.order.compareTo(b.order));
    return LessonModel(
      id: lesson.id,
      order: lesson.order,
      level: lesson.level,
      phonemes: sortedPhonemes,
      totalExercises: lesson.totalExercises,
      completedExercises: lesson.completedExercises,
    );
  }
}
