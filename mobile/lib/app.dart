import 'package:flutter/material.dart';
import 'core/di/injection.dart';
import 'core/network/token_storage.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class PhonicsApp extends StatefulWidget {
  const PhonicsApp({super.key});

  @override
  State<PhonicsApp> createState() => _PhonicsAppState();
}

class _PhonicsAppState extends State<PhonicsApp> {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(getIt<TokenStorage>());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PhonicsFriends',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _appRouter.router,
    );
  }
}
