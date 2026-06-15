import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../network/token_storage.dart';

class BiometricAuthService {
  final Dio _dio;
  final TokenStorage _tokenStorage;
  final LocalAuthentication _localAuth = LocalAuthentication();

  BiometricAuthService(this._dio, this._tokenStorage);

  Future<bool> canUseBiometrics() async {
    try {
      final canAuth = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canAuth && isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({required String reason}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
      );
    } catch (_) {
      return false;
    }
  }
}
