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
import '../../domain/entities/user_entity.dart';

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
    try {
      final dio = getIt<Dio>();
      final tokenStorage = getIt<TokenStorage>();
      
      final res1 = await dio.post('/auth/phone-login', data: {'phone_number': phoneNumber});
      final status = res1.data['status'];
      
      String? bioToken;
      if (status == 'registered') {
        bioToken = res1.data['biometric_token'];
        await tokenStorage.saveBiometricToken(bioToken!);
      } else {
        bioToken = await tokenStorage.getBiometricToken();
        if (bioToken == null || bioToken.isEmpty) {
           bioToken = 'device-token-${DateTime.now().millisecondsSinceEpoch}';
           await tokenStorage.saveBiometricToken(bioToken);
        }
      }

      final hasBio = await _biometricAuthService.canUseBiometrics();
      if (hasBio) {
        final authenticated = await _biometricAuthService.authenticate(
          reason: 'Please authenticate to access the Parent Dashboard',
        );
        if (!authenticated) {
          emit(const AuthFailureState('Biometric authentication failed.'));
          return;
        }
      }

      final res2 = await dio.post('/auth/verify-biometric', data: {
         'phone_number': phoneNumber,
         'biometric_token': bioToken,
      });
      
      final access = res2.data['access_token'];
      await tokenStorage.saveTokens(accessToken: access, refreshToken: access);
      await tokenStorage.saveUserRole('PARENT');
      
      // Fetch real user data from backend
      final userRes = await dio.get('/users/me');
      final userData = userRes.data;
      
      emit(AuthSuccess(UserEntity(
        id: userData['id'] as int,
        name: userData['name'] as String,
        email: userData['email'] as String? ?? '',
        phoneNumber: userData['phone_number'] as String? ?? '',
        ageGroup: userData['age_group'] as int? ?? 0,
        role: userData['role'] as String,
        userName: userData['user_name'] as String? ?? '',
      )));
    } catch (e) {
      if (e is DioException) {
         emit(AuthFailureState(e.response?.data?['detail'] ?? e.message ?? 'Login failed'));
      } else {
         emit(AuthFailureState(e.toString()));
      }
    }
  }

  Future<void> register({
    required String name,
    required String phoneNumber,
  }) async {
    // Unused in new flow, handled implicitly by login
    emit(const AuthFailureState('Registration is handled by login.'));
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
