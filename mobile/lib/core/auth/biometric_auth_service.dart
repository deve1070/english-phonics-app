import 'package:dio/dio.dart';
import 'package:local_auth/local_auth.dart';
import '../constants/app_constants.dart';
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
      // local_auth 3.x dropped the `options:`/`AuthenticationOptions`
      // parameter — stickyAuth is now `persistAcrossBackgrounding`.
      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  /// Biometric-gates access to the parent dashboard and returns a usable
  /// parent JWT, or null if the gate failed or no parent session can be
  /// recovered.
  ///
  /// Prefers the parent JWT stashed when the parent switched into a child
  /// session. If there isn't one (fresh install, cleared storage), it
  /// redeems the stored biometric_token via `/auth/passkey-login`, which
  /// rotates that token server-side — the new one must be persisted.
  Future<String?> authenticateParent() async {
    final passed = await authenticate(
      reason: 'Authenticate to open the Parent Dashboard',
    );
    if (!passed) return null;

    final stashed = await _tokenStorage.getParentAccessToken();
    if (stashed != null && stashed.isNotEmpty) return stashed;

    final biometricToken = await _tokenStorage.getBiometricToken();
    if (biometricToken == null || biometricToken.isEmpty) return null;

    try {
      final response = await _dio.post(
        ApiConstants.passkeyLogin,
        data: {'biometric_token': biometricToken},
      );

      final rotated = (response.data['biometric_token'] ?? '').toString();
      if (rotated.isNotEmpty) {
        await _tokenStorage.saveBiometricToken(rotated);
      }

      final accessToken = (response.data['access_token'] ?? '').toString();
      if (accessToken.isEmpty) return null;

      await _tokenStorage.saveParentAccessToken(accessToken);
      return accessToken;
    } on DioException {
      return null;
    }
  }
}
