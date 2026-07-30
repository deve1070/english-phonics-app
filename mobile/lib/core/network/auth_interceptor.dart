import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import 'token_storage.dart';

/// Attaches the right bearer token per request and, on a 401, tries to
/// recover the session by redeeming the biometric_token.
///
/// There is no `/auth/refresh` endpoint on this backend and never was —
/// auth is a two-token model (7-day access_token JWT + a rotating
/// biometric_token redeemed at `/auth/passkey-login`). The previous
/// implementation here called `/auth/refresh` with a `refresh_token` that
/// is always empty, so recovery could never succeed.
class AuthInterceptor extends Interceptor {
  final TokenStorage _tokenStorage;
  final Dio _dio;
  bool _isRecovering = false;

  AuthInterceptor(this._tokenStorage, this._dio);

  /// Endpoints that must never carry an Authorization header — they either
  /// establish a session or are the recovery call itself.
  static bool _isUnauthenticatedRoute(String path) =>
      path.contains(ApiConstants.login) ||
      path.contains(ApiConstants.register) ||
      path.contains(ApiConstants.passkeyLogin) ||
      path.contains(ApiConstants.joinWithInvite);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isUnauthenticatedRoute(options.path)) {
      handler.next(options);
      return;
    }

    // Parent APIs must use the parent's JWT even while the active session
    // token is the child's short-lived one.
    final isParentApi = options.path.startsWith('/parents');
    final token = isParentApi
        ? (await _tokenStorage.getParentAccessToken() ??
            await _tokenStorage.getAccessToken())
        : await _tokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final path = err.requestOptions.path;

    if (err.response?.statusCode != 401 ||
        _isRecovering ||
        _isUnauthenticatedRoute(path)) {
      handler.next(err);
      return;
    }

    final biometricToken = await _tokenStorage.getBiometricToken();
    if (biometricToken == null || biometricToken.isEmpty) {
      // Nothing to recover with — clear tokens so the router guard sends
      // the user back to login.
      await _tokenStorage.clearTokens();
      handler.next(err);
      return;
    }

    _isRecovering = true;
    try {
      final recovered = await _redeemBiometricToken(biometricToken);
      if (recovered) {
        // Re-read rather than reusing the value: a parent-scoped request
        // needs the parent JWT, and the recovery above wrote both.
        final isParentApi = path.startsWith('/parents');
        final token = isParentApi
            ? (await _tokenStorage.getParentAccessToken() ??
                await _tokenStorage.getAccessToken())
            : await _tokenStorage.getAccessToken();

        err.requestOptions.headers['Authorization'] = 'Bearer $token';
        final retryDio = Dio(_dio.options);
        final response = await retryDio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      }
      await _tokenStorage.clearTokens();
    } catch (_) {
      await _tokenStorage.clearTokens();
    } finally {
      _isRecovering = false;
    }

    handler.next(err);
  }

  /// Exchanges the stored biometric_token for a fresh access_token. The
  /// server rotates the biometric_token on every use, so the new one must
  /// be persisted or the next recovery will fail.
  Future<bool> _redeemBiometricToken(String biometricToken) async {
    final authDio = Dio(_dio.options);
    final response = await authDio.post(
      ApiConstants.passkeyLogin,
      data: {'biometric_token': biometricToken},
    );

    if (response.statusCode != 200) return false;

    final rotated = (response.data['biometric_token'] ?? '').toString();
    if (rotated.isNotEmpty) {
      await _tokenStorage.saveBiometricToken(rotated);
    }

    final accessToken = (response.data['access_token'] ?? '').toString();
    if (accessToken.isEmpty) return false;

    await _tokenStorage.saveTokens(accessToken: accessToken);

    // The redeemed token belongs to the account that owns the device
    // session — the parent. Keep the parent stash in sync so parent-scoped
    // calls recover too.
    if (await _tokenStorage.isParent) {
      await _tokenStorage.saveParentAccessToken(accessToken);
    }
    return true;
  }
}
