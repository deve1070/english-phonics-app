import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/token_storage.dart';
import '../../../../core/session/day_plan.dart';
import '../../../../core/session/learning_cursor.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../../auth/data/repositories/auth_repository_impl.dart';
import 'package:dio/dio.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final AuthRepositoryImpl _authRepo;
  final TokenStorage _tokenStorage;

  ProfileCubit(this._authRepo, this._tokenStorage)
      : super(const ProfileInitial());

  factory ProfileCubit.create() {
    final dio = getIt<Dio>();
    final tokenStorage = getIt<TokenStorage>();
    final dataSource = AuthRemoteDataSource(dio, tokenStorage);
    final repo = AuthRepositoryImpl(dataSource, tokenStorage);
    return ProfileCubit(repo, tokenStorage);
  }

  Future<void> load() async {
    emit(const ProfileLoading());
    final result = await _authRepo.getCurrentUser();
    result.fold(
      (f) => emit(ProfileError(f.message)),
      (user) => emit(ProfileLoaded(user)),
    );
  }

  Future<void> logout() async {
    await _tokenStorage.clearTokens();
    // The resume position is on the device, not in the token, so clearing
    // the session does not clear it. Left behind, the next person to sign
    // in on this phone — a sibling, most likely — would be dropped into
    // the middle of somebody else's lesson.
    await getIt<CursorStore>().clear();
    // Same reasoning for how much of today's plan is finished: a sibling
    // signing in next would otherwise be told their day was nearly over.
    await getIt<DayRunner>().clear();
    emit(const ProfileLoggedOut());
  }
}
