import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../phonics/data/datasources/lessons_remote_datasource.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../../../core/network/token_storage.dart';
import 'progress_state.dart';

class ProgressCubit extends Cubit<ProgressState> {
  final LessonsRemoteDataSource _lessonsDataSource;
  final AuthRemoteDataSource _authDataSource;

  ProgressCubit(this._lessonsDataSource, this._authDataSource)
      : super(const ProgressInitial());

  factory ProgressCubit.create() {
    final dio = getIt<Dio>();
    final tokenStorage = getIt<TokenStorage>();
    return ProgressCubit(
      LessonsRemoteDataSource(dio),
      AuthRemoteDataSource(dio, tokenStorage),
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

  /// There is no student-scoped feedback endpoint on this backend — the
  /// old `/progress/me/feedback` route was removed along with the rest of
  /// the progress feature, so this call 404'd on every load and silently
  /// fell through to the placeholder below. Returning it directly skips a
  /// guaranteed-failing round trip on every open of the progress screen.
  ///
  /// Per-exercise score history exists only on the parent-facing
  /// `GET /parents/children/{id}/progress`. A student-scoped equivalent
  /// would be a small backend addition if this screen should show real
  /// numbers.
  Future<Map<String, dynamic>> _fetchFeedback() async {
    return {'message': 'Start practising to get personalised feedback!'};
  }
}
