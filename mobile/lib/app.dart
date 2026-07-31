import 'package:flutter/material.dart';
import 'core/di/injection.dart';
import 'core/network/token_storage.dart';
import 'core/router/app_router.dart';
import 'core/screen_time/screen_time_service.dart';
import 'core/theme/app_theme.dart';

class PhonicsApp extends StatefulWidget {
  const PhonicsApp({super.key});

  @override
  State<PhonicsApp> createState() => _PhonicsAppState();
}

class _PhonicsAppState extends State<PhonicsApp> with WidgetsBindingObserver {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(getIt<TokenStorage>());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Screen time should reflect time actually spent in the app.
  ///
  /// Without this, a child who backgrounds or force-quits the app leaves the
  /// session open forever. The server only sums *closed* sessions, so that
  /// time is never counted at all and the daily limit never trips — while
  /// the dangling row also stops the next start-session from opening a fresh
  /// one. Closing on pause banks the time; reopening on resume means only
  /// foreground time counts.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final screenTime = getIt<ScreenTimeService>();

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Keep the child id: they haven't left their session, the app just
        // went to the background.
        screenTime.endSession(forget: false);
      case AppLifecycleState.resumed:
        screenTime.resumeSession();
      case AppLifecycleState.inactive:
        // Transient (call overlay, app-switcher preview). Not a real exit.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Phonics ኢትዮጵያ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _appRouter.router,
    );
  }
}
