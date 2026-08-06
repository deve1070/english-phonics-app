import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/mascot/kiki.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/network/token_storage.dart';
import '../../../core/session/learning_cursor.dart';
import '../../../core/di/injection.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: -16).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    // Navigate after 2.8s
    Future.delayed(const Duration(milliseconds: 2800), _navigate);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  /// Align stored role with `/users/me` so a child JWT is not paired with role PARENT.
  Future<void> _syncRoleFromProfile() async {
    try {
      final dio = getIt<Dio>();
      final res = await dio.get(ApiConstants.me);
      final raw = res.data['role'];
      final apiRole = raw is String ? raw.toUpperCase() : '';
      if (apiRole.isEmpty) return;
      await getIt<TokenStorage>().saveUserRole(apiRole);
    } catch (_) {
      // Offline or expired token — keep cached role
    }
  }

  /// Straight back to the step they stopped on, or Home if there is none.
  ///
  /// The whole point of the cursor: a child who was halfway through a
  /// sound yesterday should not have to find their way back to it, because
  /// finding their way back is a navigation problem and they are four.
  ///
  /// Reads the device's copy first, so this costs nothing on a normal
  /// launch and works with no connection at all. The server is asked only
  /// when the device has nothing — a reinstall or a new phone — and even
  /// then it gives up after a few seconds: starting from the top is a
  /// worse outcome than resuming, but a far better one than a child
  /// watching a splash screen wondering if the app is broken.
  Future<String> _whereTheChildLeftOff() async {
    final cursor = await getIt<CursorStore>().read();
    if (cursor == null) return AppRoutes.home;
    return cursor.routeUnder(AppRoutes.lessons);
  }

  Future<void> _navigate() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    final hasToken = await getIt<TokenStorage>().hasValidToken();

    if (!mounted) return;

    if (hasToken) {
      await _syncRoleFromProfile();
      if (!mounted) return;
      final role = await getIt<TokenStorage>().getUserRole();
      if (!mounted) return;
      if (role == 'PARENT') {
        context.go(AppRoutes.parentDashboard);
      } else {
        context.go(await _whereTheChildLeftOff());
      }
    } else if (!onboardingDone) {
      context.go(AppRoutes.onboarding);
    } else {
      context.go(AppRoutes.phoneLogin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF9F0), Color(0xFFFFEDD8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // Background circles — decorative
            Positioned(
              top: -60,
              right: -60,
              child:
                  _Circle(size: 200, color: AppColors.coral.withOpacity(0.08)),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child:
                  _Circle(size: 260, color: AppColors.teal.withOpacity(0.08)),
            ),
            Positioned(
              top: size.height * 0.3,
              left: -40,
              child:
                  _Circle(size: 120, color: AppColors.yellow.withOpacity(0.15)),
            ),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Mascot — bouncing
                  AnimatedBuilder(
                    animation: _bounceAnimation,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, _bounceAnimation.value),
                      child: child,
                    ),
                    child: const Kiki(size: 220),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                      .scale(
                        begin: const Offset(0.7, 0.7),
                        end: const Offset(1.0, 1.0),
                        duration: 600.ms,
                        curve: Curves.elasticOut,
                      ),

                  const SizedBox(height: 32),

                  // App name
                  Text(
                    'PhonicsFriends',
                    style: AppTextStyles.displayLarge.copyWith(
                      color: AppColors.coral,
                      fontSize: 38,
                    ),
                  ).animate(delay: 300.ms).fadeIn(duration: 500.ms).slideY(
                      begin: 0.3,
                      end: 0,
                      duration: 500.ms,
                      curve: Curves.easeOut),

                  const SizedBox(height: 10),

                  // Tagline
                  Text(
                    'Learn to read, one sound at a time 🎵',
                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 15),
                    textAlign: TextAlign.center,
                  ).animate(delay: 500.ms).fadeIn(duration: 500.ms),

                  const Spacer(flex: 3),

                  // Loading dots
                  _LoadingDots()
                      .animate(delay: 800.ms)
                      .fadeIn(duration: 400.ms),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Decorative circle ────────────────────────────────────────────
class _Circle extends StatelessWidget {
  final double size;
  final Color color;
  const _Circle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ── Animated loading dots ────────────────────────────────────────
class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final t = (_controller.value - i * 0.2).clamp(0.0, 1.0);
            final scale = (1 + 0.5 * (1 - (2 * t - 1).abs())).clamp(1.0, 1.5);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: [
                      AppColors.coral,
                      AppColors.teal,
                      AppColors.yellow,
                    ][i],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

