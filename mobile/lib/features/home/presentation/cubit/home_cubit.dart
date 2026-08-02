import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';

import '../../../../core/network/token_storage.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../../auth/data/repositories/auth_repository_impl.dart';
import '../../../engagement/data/engagement_models.dart';
import '../../../engagement/data/engagement_remote_datasource.dart';
import '../../../phonics/data/datasources/lessons_remote_datasource.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final AuthRepositoryImpl _authRepo;
  final LessonsRemoteDataSource _lessonsDataSource;
  final EngagementRemoteDataSource _engagement;

  HomeCubit(this._authRepo, this._lessonsDataSource, this._engagement)
      : super(const HomeInitial());

  factory HomeCubit.create() {
    final dio = getIt<Dio>();
    final tokenStorage = getIt<TokenStorage>();
    final authDataSource = AuthRemoteDataSource(dio, tokenStorage);
    final authRepo = AuthRepositoryImpl(authDataSource, tokenStorage);
    final lessonsDataSource = LessonsRemoteDataSource(dio);
    return HomeCubit(
      authRepo,
      lessonsDataSource,
      EngagementRemoteDataSource(dio),
    );
  }

  Future<void> load() async {
    emit(const HomeLoading());
    try {
      final userResult = await _authRepo.getCurrentUser();
      final user = userResult.fold((f) => throw Exception(f.message), (u) => u);
      final lessons = await _lessonsDataSource.getLessons();

      // Quest, streak and goal are fetched together and after the lessons,
      // not before: they decorate the home screen, and a child whose
      // network is flaky must still get their lesson path. All three
      // datasource calls fall back to an empty value rather than throwing,
      // so none of them can take the home screen down with it.
      final results = await Future.wait([
        _engagement.getTodaysQuest(),
        _engagement.getStreak(),
        _engagement.getGoal(),
      ]);

      emit(HomeLoaded(
        user: user,
        lessons: lessons,
        quest: results[0] as DailyQuest,
        streak: results[1] as StreakInfo,
        goal: results[2] as WeeklyGoal,
      ));
    } on DioException catch (e) {
      emit(HomeError(e.message ?? 'Network error'));
    } catch (e) {
      emit(HomeError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> logout() async {
    await getIt<TokenStorage>().clearTokens();
  }
}
