import 'package:dio/dio.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/exercise_model.dart';
import '../models/lesson_model.dart';

class ExercisesRemoteDataSource {
  final Dio _dio;
  ExercisesRemoteDataSource(this._dio);

  Future<List<ExerciseModel>> getExercisesForLesson(int lessonId) async {
    final response = await _dio.get(
      ApiConstants.lessonExercises(lessonId),
    );
    // Backend returns { lesson_id, level, exercises: [...] }
    final data = response.data;
    final List<dynamic> list = data is Map ? (data['exercises'] ?? []) : data;
    return list
        .map((e) => ExerciseModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LessonModel> getLessonDetail(int lessonId) async {
    final response = await _dio.get(ApiConstants.lessonById(lessonId));
    return LessonModel.fromJson(response.data as Map<String, dynamic>);
  }
}
