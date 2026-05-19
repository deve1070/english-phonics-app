import 'package:dio/dio.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/token_storage.dart';
import '../models/user_model.dart';

class AuthRemoteDataSource {
  final Dio _dio;
  final TokenStorage _tokenStorage;

  AuthRemoteDataSource(this._dio, this._tokenStorage);

  Future<UserModel> login({
    required String phoneNumber,
  }) async {
    final response = await _dio.post(
      ApiConstants.login,
      data: {
        'phone_number': phoneNumber,
      },
    );

    final accessToken = (response.data['access_token'] ?? '').toString();
    if (accessToken.isEmpty) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Login succeeded but access_token missing',
      );
    }

    await _tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: (response.data['refresh_token'] ?? '').toString(),
    );

    final biometricToken = (response.data['biometric_token'] ?? '').toString();
    if (biometricToken.isNotEmpty) {
      await _tokenStorage.saveBiometricToken(biometricToken);
    }

    // Fetch real user data immediately after login
    return getCurrentUser();
  }

  Future<UserModel> register({
    required String name,
    required String phoneNumber,
  }) async {
    final response = await _dio.post(
      ApiConstants.register,
      data: {
        'name': name,
        'phone_number': phoneNumber,
      },
    );

    final accessToken = (response.data['access_token'] ?? '').toString();
    final biometricToken = (response.data['biometric_token'] ?? '').toString();
    
    if (accessToken.isNotEmpty) {
      await _tokenStorage.saveTokens(accessToken: accessToken, refreshToken: '');
    }
    if (biometricToken.isNotEmpty) {
      await _tokenStorage.saveBiometricToken(biometricToken);
    }

    return getCurrentUser();
  }

  Future<UserModel> passkeyLogin({
    required String biometricToken,
  }) async {
    final response = await _dio.post(
      '/auth/passkey-login',
      data: {
        'biometric_token': biometricToken,
      },
    );

    final accessToken = (response.data['access_token'] ?? '').toString();
    final newBiometricToken = (response.data['biometric_token'] ?? '').toString();

    if (accessToken.isNotEmpty) {
      await _tokenStorage.saveTokens(accessToken: accessToken, refreshToken: '');
    }
    if (newBiometricToken.isNotEmpty) {
      await _tokenStorage.saveBiometricToken(newBiometricToken);
    }

    return getCurrentUser();
  }

  // FIX 2: call real GET /users/me instead of returning a stub
  Future<UserModel> getCurrentUser() async {
    try {
      final response = await _dio.get(ApiConstants.me);
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      // If /users/me fails (e.g. token expired), rethrow so caller can handle
      rethrow;
    }
  }
}
