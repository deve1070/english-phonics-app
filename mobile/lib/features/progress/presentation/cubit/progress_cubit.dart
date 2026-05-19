import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../phonics/data/datasources/lessons_remote_datasource.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../../../core/network/token_storage.dart';
import 'progress_state.dart';

class ProgressCubit extends Cubit<ProgressState> {
  final LessonsRemoteDataSource _lessonsDataSource;
  final AuthRemoteDataSource _authDataSource;
  final Dio _dio;

  ProgressCubit(this._lessonsDataSource, this._authDataSource, this._dio)
      : super(const ProgressInitial());

  factory ProgressCubit.create() {
    final dio = getIt<Dio>();
    final tokenStorage = getIt<TokenStorage>();
    return ProgressCubit(
      LessonsRemoteDataSource(dio),
      AuthRemoteDataSource(dio, tokenStorage),
      dio,
    );
  }

  Future<void> load() async {
    emit(const ProgressLoading());
    try {
      final results = await Future.wait([
        _authDataSource.getCurrentUser(),
        _lessonsDataSource.getLessons(),
        _fetchFeedback(),
      ]);

      final lessons = results[1] as dynamic;
      final feedback = results[2] as Map<String, dynamic>;

      emit(ProgressLoaded(
        lessons: lessons,

        // FIX: removed hardcoded streakDays: 3 — set to 0 until real endpoint
        streakDays: 0,
        feedbackMessage: feedback['message'] as String? ??
            feedback['feedback'] as String? ??
            'Keep practising!',
        averageRecentScore:
            (feedback['average_recent_score'] as num?)?.toDouble(),
        practicedCount: (feedback['practiced_count'] as int?) ?? 0,
      ));
    } on DioException catch (e) {
      emit(ProgressError(e.message ?? 'Network error'));
    } catch (e) {
      emit(ProgressError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<Map<String, dynamic>> _fetchFeedback() async {
    try {
      final response = await _dio.get(ApiConstants.feedback);
      return response.data as Map<String, dynamic>;
    } catch (_) {
      return {'message': 'Start practising to get personalised feedback!'};
    }
  }
}
