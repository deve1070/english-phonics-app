import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../auth/biometric_unlock_service.dart';
import '../constants/app_constants.dart';
import '../network/auth_interceptor.dart';
import '../network/token_storage.dart';

// ── Uncomment after: flutter pub add local_auth ───────────────────
// import 'package:local_auth/local_auth.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // ── TokenStorage ──────────────────────────────────────────────
  final tokenStorage = TokenStorage();
  getIt.registerSingleton<TokenStorage>(tokenStorage);

  // ── Dio ───────────────────────────────────────────────────────
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // FIX: AuthInterceptor constructor is (TokenStorage, Dio)
  dio.interceptors.add(AuthInterceptor(tokenStorage, dio));
  dio.interceptors.add(PrettyDioLogger(
    requestHeader: true,
    requestBody: true,
    responseBody: true,
    error: true,
    compact: true,
  ));

  getIt.registerSingleton<Dio>(dio);

  getIt.registerLazySingleton<BiometricUnlockService>(
    () => BiometricUnlockService(),
  );

  // ── LocalAuthentication (biometric) ───────────────────────────
  // Enabled after: flutter pub add local_auth
  // AND changing android/app/src/main/kotlin/.../MainActivity.kt
  //   to extend FlutterFragmentActivity (not FlutterActivity)
  // AND setting minSdkVersion 23 in android/app/build.gradle
  //
  // Uncomment these lines when ready:
  //
  // final localAuth = LocalAuthentication();
  // getIt.registerSingleton<LocalAuthentication>(localAuth);
}
