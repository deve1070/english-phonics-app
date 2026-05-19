import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';

import '../../../../core/network/token_storage.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../../auth/data/repositories/auth_repository_impl.dart';
import '../../../phonics/data/datasources/lessons_remote_datasource.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final AuthRepositoryImpl _authRepo;
  final LessonsRemoteDataSource _lessonsDataSource;

  HomeCubit(this._authRepo, this._lessonsDataSource)
      : super(const HomeInitial());

  factory HomeCubit.create() {
    final dio = getIt<Dio>();
    final tokenStorage = getIt<TokenStorage>();
    final authDataSource = AuthRemoteDataSource(dio, tokenStorage);
    final authRepo = AuthRepositoryImpl(authDataSource, tokenStorage);
    final lessonsDataSource = LessonsRemoteDataSource(dio);
    return HomeCubit(authRepo, lessonsDataSource);
  }

  Future<void> load() async {
    emit(const HomeLoading());
    try {
      final userResult = await _authRepo.getCurrentUser();
      final user = userResult.fold((f) => throw Exception(f.message), (u) => u);
      final lessons = await _lessonsDataSource.getLessons();

      emit(HomeLoaded(
        user: user,
        lessons: lessons,
        streakDays: 3, // TODO: wire from backend when streak endpoint is ready
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
