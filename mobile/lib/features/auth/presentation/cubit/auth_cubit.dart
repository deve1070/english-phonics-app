import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usercases/login_usecase.dart';
import '../../domain/usercases/register_usecase.dart';
import '../../domain/usercases/passkey_login_usecase.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/token_storage.dart';
import 'auth_state.dart';
import '../../domain/entities/user_entity.dart';

/// Owns the passwordless auth flow. Deliberately holds no
/// BiometricAuthService: the device biometric prompt gates entry to the
/// *parent dashboard* (see ParentDashboardButton), not sign-in itself.
/// Gating sign-in on biometrics locked out devices without the hardware.
class AuthCubit extends Cubit<AuthState> {
  final LoginUseCase _loginUseCase;
  final RegisterUseCase _registerUseCase;
  final PasskeyLoginUseCase _passkeyLoginUseCase;

  AuthCubit({
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
    required PasskeyLoginUseCase passkeyLoginUseCase,
  })  : _loginUseCase = loginUseCase,
        _registerUseCase = registerUseCase,
        _passkeyLoginUseCase = passkeyLoginUseCase,
        super(const AuthInitial());

  factory AuthCubit.create() {
    final tokenStorage = getIt<TokenStorage>();
    final dio = getIt<Dio>();
    final dataSource = AuthRemoteDataSource(dio, tokenStorage);
    final repo = AuthRepositoryImpl(dataSource, tokenStorage);
    return AuthCubit(
      loginUseCase: LoginUseCase(repo),
      registerUseCase: RegisterUseCase(repo),
      passkeyLoginUseCase: PasskeyLoginUseCase(repo),
    );
  }

  /// Passwordless login: phone number only. `POST /auth/login` returns the
  /// access_token and biometric_token in one shot — there is no OTP step
  /// and no separate biometric verification call.
  Future<void> login({
    required String phoneNumber,
  }) async {
    emit(const AuthLoading());
    final result = await _loginUseCase(phoneNumber: phoneNumber);
    await result.fold(
      (failure) async => emit(AuthFailureState(failure.message)),
      (user) async => _onAuthenticated(user),
    );
  }

  Future<void> register({
    required String name,
    required String phoneNumber,
  }) async {
    emit(const AuthLoading());
    final result = await _registerUseCase(name: name, phoneNumber: phoneNumber);
    await result.fold(
      (failure) async => emit(AuthFailureState(failure.message)),
      (user) async => _onAuthenticated(user),
    );
  }

  /// Persists the role and, for parents, stashes the JWT under a dedicated
  /// key so parent-scoped APIs keep working after the app switches the
  /// active token to a child's short-lived session token.
  Future<void> _onAuthenticated(UserEntity user) async {
    final tokenStorage = getIt<TokenStorage>();
    await tokenStorage.saveUserRole(user.role);

    if (user.role.toUpperCase() == 'PARENT') {
      final accessToken = await tokenStorage.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        await tokenStorage.saveParentAccessToken(accessToken);
      }
    }

    emit(AuthSuccess(user));
  }

  Future<void> attemptPasskeyLogin() async {
    emit(const AuthLoading());
    final bioToken = await getIt<TokenStorage>().getBiometricToken();
    if (bioToken == null || bioToken.isEmpty) {
      emit(const AuthInitial());
      return;
    }

    // Silent auto-login. Deliberately not gated on canUseBiometrics(): the
    // biometric_token is a device "stay signed in" credential and works on
    // devices with no biometric hardware at all. Gating it here meant those
    // devices could never auto-login. The biometric prompt belongs on the
    // parent-dashboard gate, not on app launch.
    final result = await _passkeyLoginUseCase(biometricToken: bioToken);
    await result.fold(
      // Token rejected or expired — fall back to the normal login screen.
      (failure) async => emit(const AuthInitial()),
      (user) async => _onAuthenticated(user),
    );
  }

  void reset() => emit(const AuthInitial());
}
