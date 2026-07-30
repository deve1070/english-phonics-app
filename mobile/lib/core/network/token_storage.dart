import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class TokenStorage {
  final FlutterSecureStorage _storage;

  TokenStorage()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  // ── Access token ──────────────────────────────────────────────
  // No refresh token: this backend issues a 7-day access_token plus a
  // separate biometric_token (below) and has no /auth/refresh endpoint.
  Future<void> saveTokens({required String accessToken}) =>
      _storage.write(key: StorageKeys.accessToken, value: accessToken);

  Future<String?> getAccessToken() =>
      _storage.read(key: StorageKeys.accessToken);

  Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      return false;
    }
    
    // Decode JWT and check expiry
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return false; // Invalid JWT format
      }
      
      // Decode payload (second part)
      final payload = _decodeBase64(parts[1]);
      final payloadMap = json.decode(payload) as Map<String, dynamic>;
      
      // Check expiry time (exp is in seconds since epoch)
      final exp = payloadMap['exp'] as int?;
      if (exp == null) {
        return true; // No expiry claim, assume valid
      }
      
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return now < exp;
    } catch (e) {
      // If decoding fails, assume token is invalid
      return false;
    }
  }
  
  String _decodeBase64(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (str.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
    }
    return utf8.decode(base64.decode(output));
  }

  Future<String?> getSubscriptionStatus() =>
      _storage.read(key: StorageKeys.subscriptionStatus);

  Future<void> saveSubscriptionStatus(String status) =>
      _storage.write(key: StorageKeys.subscriptionStatus, value: status);

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: StorageKeys.accessToken),
      _storage.delete(key: StorageKeys.refreshToken),
      _storage.delete(key: StorageKeys.userId),
      _storage.delete(key: StorageKeys.userRole),
      _storage.delete(key: StorageKeys.subscriptionStatus),
      _storage.delete(key: StorageKeys.childToken),
      _storage.delete(key: StorageKeys.parentAccessToken),
      _storage.delete(key: StorageKeys.biometricToken),
      _storage.delete(key: StorageKeys.biometricUnlockEnabled),
    ]);
  }

  /// Call whenever the app holds a known parent JWT (phone signup, OTP login, biometric).
  Future<void> saveParentAccessToken(String token) =>
      _storage.write(key: StorageKeys.parentAccessToken, value: token);

  Future<String?> getParentAccessToken() =>
      _storage.read(key: StorageKeys.parentAccessToken);

  Future<void> clearParentAccessToken() =>
      _storage.delete(key: StorageKeys.parentAccessToken);

  Future<void> clearAll() => _storage.deleteAll();

  // ── User role (NEW) ───────────────────────────────────────────
  Future<void> saveUserRole(String role) =>
      _storage.write(key: StorageKeys.userRole, value: role.toUpperCase());

  Future<String?> getUserRole() => _storage.read(key: StorageKeys.userRole);

  Future<bool> get isParent async {
    final role = await getUserRole();
    return role == 'PARENT';
  }

  // ── Biometric token (NEW) ─────────────────────────────────────
  /// Stored encrypted. Retrieved only after device biometric passes.
  Future<void> saveBiometricToken(String token) =>
      _storage.write(key: StorageKeys.biometricToken, value: token);

  Future<String?> getBiometricToken() =>
      _storage.read(key: StorageKeys.biometricToken);

  Future<void> clearBiometricToken() =>
      _storage.delete(key: StorageKeys.biometricToken);

  Future<void> setBiometricUnlockEnabled(bool enabled) => _storage.write(
        key: StorageKeys.biometricUnlockEnabled,
        value: enabled ? '1' : '0',
      );

  Future<bool> get isBiometricUnlockEnabled async =>
      (await _storage.read(key: StorageKeys.biometricUnlockEnabled)) == '1';

  // ── Child token (NEW) ─────────────────────────────────────────
  /// Preserved when parent temporarily switches to their dashboard.
  /// Restored when parent exits back to child view.
  Future<void> saveChildToken(String token) =>
      _storage.write(key: StorageKeys.childToken, value: token);

  Future<String?> getChildToken() => _storage.read(key: StorageKeys.childToken);

  Future<void> clearChildToken() =>
      _storage.delete(key: StorageKeys.childToken);
}
