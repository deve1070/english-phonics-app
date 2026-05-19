import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import 'token_storage.dart';

class AuthInterceptor extends Interceptor {
  final TokenStorage _tokenStorage;
  final Dio _dio;
  bool _isRefreshing = false;

  AuthInterceptor(this._tokenStorage, this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Never attach token to the refresh or OTP endpoints
    if (options.path.contains('/auth/refresh') ||
        options.path.contains('/auth/send-otp') ||
        options.path.contains('/auth/verify-otp') ||
        options.path.contains('/auth/register-phone') ||
        options.path.contains('/auth/biometric-login') ||
        options.path.contains('/auth/join')) {
      handler.next(options);
      return;
    }

    // Parent APIs must use the parent's JWT even while the active session token is the child's.
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
    final isRefreshCall = err.requestOptions.path.contains('/auth/refresh');

    if (err.response?.statusCode == 401 && !isRefreshCall && !_isRefreshing) {
      // FIX: Phone auth users have no refresh token.
      // If refresh token is empty, skip refresh entirely — go straight to
      // clear tokens so the guard redirects to phone login.
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        // No refresh token — session expired for phone auth user
        // Clear tokens so router guard redirects to login
        await _tokenStorage.clearTokens();
        handler.next(err);
        return;
      }

      _isRefreshing = true;
      try {
        final refreshed = await _refreshToken(refreshToken);
        if (refreshed) {
          final token = await _tokenStorage.getAccessToken();
          err.requestOptions.headers['Authorization'] = 'Bearer $token';
          final retryDio = Dio(_dio.options);
          final response = await retryDio.fetch(err.requestOptions);
          handler.resolve(response);
          return;
        }
      } catch (_) {
        await _tokenStorage.clearTokens();
      } finally {
        _isRefreshing = false;
      }
    }
    handler.next(err);
  }

  Future<bool> _refreshToken(String refreshToken) async {
    final refreshDio = Dio(_dio.options);
    final response = await refreshDio.post(
      ApiConstants.refreshToken,
      data: {'refresh_token': refreshToken},
    );

    if (response.statusCode == 200) {
      await _tokenStorage.saveTokens(
        accessToken: response.data['access_token'],
        refreshToken: response.data['refresh_token'] ?? refreshToken,
      );
      return true;
    }
    return false;
  }
}
