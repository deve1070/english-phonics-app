import 'package:local_auth/local_auth.dart';

/// Device biometric / device credential (PIN, pattern, fingerprint, Face ID).
class BiometricUnlockService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Device can show a biometric prompt or fall back to device PIN / pattern.
  Future<bool> get canUnlock async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlock({required String localizedReason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
