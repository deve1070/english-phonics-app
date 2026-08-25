import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../auth/biometric_unlock_service.dart';
import '../constants/app_constants.dart';
import '../network/auth_interceptor.dart';
import '../network/token_storage.dart';
import '../screen_time/screen_time_service.dart';
import '../session/day_plan.dart';
import '../session/learning_cursor.dart';
import '../../features/lessons/presentation/widgets/session_summary_sheet.dart';

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

  getIt.registerLazySingleton<ScreenTimeService>(
    () => ScreenTimeService(dio, tokenStorage),
  );

  // Where the child stopped, so the next launch can put them back rather
  // than asking them to find their way there. A singleton because it is
  // written from the lesson screen and read from the splash, which never
  // exist at the same time.
  getIt.registerLazySingleton<CursorStore>(() => CursorStore(dio));

  // Decides what the child does next, at launch and after each activity.
  // Holds the cursor because "carry on with the lesson" is a position, not
  // a screen. A singleton for the same reason as the cursor: it is asked
  // from the splash and from screens that never coexist with it.
  getIt.registerLazySingleton<DayRunner>(() => DayRunner(getIt<CursorStore>()));

  // Accumulates the current sitting so the closing summary has something to
  // report. A singleton because a session spans several exercise screens —
  // scoping it to any one of them would reset the tally on every navigation.
  getIt.registerLazySingleton<SessionTracker>(() => SessionTracker());
}
