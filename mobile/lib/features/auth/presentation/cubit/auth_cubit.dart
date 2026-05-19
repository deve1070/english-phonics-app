import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usercases/login_usecase.dart';
import '../../domain/usercases/register_usecase.dart';
import '../../domain/usercases/passkey_login_usecase.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/token_storage.dart';
import '../../../../core/auth/biometric_auth_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final LoginUseCase _loginUseCase;
  final RegisterUseCase _registerUseCase;
  final PasskeyLoginUseCase _passkeyLoginUseCase;
  final BiometricAuthService _biometricAuthService;

  AuthCubit({
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
    required PasskeyLoginUseCase passkeyLoginUseCase,
    required BiometricAuthService biometricAuthService,
  })  : _loginUseCase = loginUseCase,
        _registerUseCase = registerUseCase,
        _passkeyLoginUseCase = passkeyLoginUseCase,
        _biometricAuthService = biometricAuthService,
        super(const AuthInitial());

  factory AuthCubit.create() {
    final tokenStorage = getIt<TokenStorage>();
    final dio = getIt<Dio>();
    final dataSource = AuthRemoteDataSource(dio, tokenStorage);
    final repo = AuthRepositoryImpl(dataSource, tokenStorage);
    final biometricAuthService = BiometricAuthService(dio, tokenStorage);
    return AuthCubit(
      loginUseCase: LoginUseCase(repo),
      registerUseCase: RegisterUseCase(repo),
      passkeyLoginUseCase: PasskeyLoginUseCase(repo),
      biometricAuthService: biometricAuthService,
    );
  }

  Future<void> login({
    required String phoneNumber,
  }) async {
    emit(const AuthLoading());
    final result = await _loginUseCase(phoneNumber: phoneNumber);
    result.fold(
      (failure) => emit(AuthFailureState(failure.message)),
      (user) => emit(AuthSuccess(user)),
    );
  }

  Future<void> register({
    required String name,
    required String phoneNumber,
  }) async {
    emit(const AuthLoading());
    final result = await _registerUseCase(
      name: name,
      phoneNumber: phoneNumber,
    );
    result.fold(
      (failure) => emit(AuthFailureState(failure.message)),
      (user) => emit(AuthSuccess(user)),
    );
  }

  Future<void> attemptPasskeyLogin() async {
    emit(const AuthLoading());
    final bioToken = await getIt<TokenStorage>().getBiometricToken();
    if (bioToken == null || bioToken.isEmpty) {
      emit(const AuthInitial());
      return;
    }

    final hasBiometrics = await _biometricAuthService.canUseBiometrics();
    if (hasBiometrics) {
      // Could use biometric prompt here if desired, 
      // but for simple app launch we just try passing the token.
      final result = await _passkeyLoginUseCase(biometricToken: bioToken);
      result.fold(
        (failure) {
          // Fall back to normal login
          emit(const AuthInitial());
        },
        (user) => emit(AuthSuccess(user)),
      );
    } else {
      emit(const AuthInitial());
    }
  }

  void reset() => emit(const AuthInitial());
}
