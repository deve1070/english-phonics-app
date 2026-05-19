import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import '../network/token_storage.dart';

/// Biometric (fingerprint/face) authentication service for parents.
///
/// Two-step process:
///   1. Device biometric prompt (local, no network)
///   2. Exchange stored biometric_token for fresh parent JWT (one network call)
///
/// Requires: flutter pub add local_auth
/// Add to AndroidManifest.xml: FlutterFragmentActivity
/// Add to Info.plist: NSFaceIDUsageDescription
class BiometricAuthService {
  final Dio _dio;
  final TokenStorage _tokenStorage;

  BiometricAuthService(this._dio, this._tokenStorage);

  /// Returns true if the device has biometrics enrolled and supported.
  Future<bool> canUseBiometrics() async {
    try {
      // Requires local_auth package
      // ignore: unnecessary_import
      final localAuth = _getLocalAuth();
      if (localAuth == null) return false;
      final canAuth = await localAuth.canCheckBiometrics as bool;
      final isSupported = await localAuth.isDeviceSupported() as bool;
      return canAuth && isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the parent for biometric verification, then exchanges
  /// the stored biometric token for a fresh parent JWT.
  /// Returns the parent access token on success, null on failure.
  Future<String?> authenticateParent() async {
    try {
      final localAuth = _getLocalAuth();
      if (localAuth == null) return null;

      final authenticated = await localAuth.authenticate(
        localizedReason: "Confirm it's you to open the parent dashboard",
        options: _getAuthOptions(),
      ) as bool;

      if (!authenticated) return null;

      final bioToken = await _tokenStorage.getBiometricToken();
      if (bioToken == null) return null;

      final response = await _dio.post('/auth/passkey-login', data: {
        'biometric_token': bioToken,
      });

      return response.data['access_token'] as String?;
    } on PlatformException {
      return null;
    } on Exception {
      return null;
    }
  }

  // These return dynamic to avoid hard import of local_auth
  // Replace with typed code once: flutter pub add local_auth
  dynamic _getLocalAuth() {
    try {
      // After adding local_auth to pubspec, replace with:
      // import 'package:local_auth/local_auth.dart';
      // return LocalAuthentication();
      return null; // placeholder until package is installed
    } catch (_) {
      return null;
    }
  }

  dynamic _getAuthOptions() {
    // After adding local_auth, replace with:
    // return const AuthenticationOptions(stickyAuth: true, biometricOnly: false);
    return null;
  }
}
