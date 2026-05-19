import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_constants.dart';
import '../network/token_storage.dart';
import 'app_routes.dart';

// existing screens
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/phonics/presentation/screens/phoneme_lesson_screen.dart';
import '../../features/pronunciation/presentation/screens/pronunciation_screen.dart';
import '../../features/spelling_bee/presentation/screens/spelling_bee_screen.dart';
import '../../features/progress/presentation/screens/progress_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/lessons/presentation/screens/lessons_list_screen.dart';
// NEW: phone auth screens
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
// NEW: join screen (child redeems invite link)
import '../../features/home/presentation/screens/join_screen.dart';
// NEW: parent screens
import '../../features/parent/presentation/screens/parent_dashboard_screen.dart';
import '../../features/parent/presentation/screens/child_progress_detail_screen.dart';
import '../../features/parent/presentation/screens/invite_links_screen.dart';

class AppRouter {
  final TokenStorage tokenStorage;

  AppRouter(this.tokenStorage);

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: _guard,
    routes: _routes,
  );

  // ── Route guard ───────────────────────────────────────────────
  Future<String?> _guard(BuildContext context, GoRouterState state) async {
    final location = state.matchedLocation;
    final isAuthenticated = await tokenStorage.hasValidToken();

    // Always allow public routes
    const publicPaths = {
      AppRoutes.splash,
      AppRoutes.onboarding,
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.phoneRegister,
      AppRoutes.phoneLogin,
      AppRoutes.joinInvite,
    };
    if (publicPaths.contains(location)) return null;

    // Unauthenticated → phone login
    if (!isAuthenticated) return AppRoutes.phoneLogin;

    // On login/register screens while authenticated → route by role
    if (location == AppRoutes.login ||
        location == AppRoutes.register ||
        location == AppRoutes.phoneLogin ||
        location == AppRoutes.phoneRegister) {
      final role = await tokenStorage.getUserRole();
      return (role == 'PARENT') ? AppRoutes.parentDashboard : AppRoutes.home;
    }

    // Parent accessing child-only routes → redirect to parent dashboard
    final role = await tokenStorage.getUserRole();
    if (role == 'PARENT' && _isChildOnlyRoute(location)) {
      return AppRoutes.parentDashboard;
    }

    return null;
  }

  bool _isChildOnlyRoute(String l) =>
      l == AppRoutes.home ||
      l == AppRoutes.spellingBee ||
      l == AppRoutes.progress;


  // ── Routes ────────────────────────────────────────────────────
  List<RouteBase> get _routes => [
        GoRoute(
            path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
        GoRoute(
            path: AppRoutes.onboarding,
            builder: (_, __) => const OnboardingScreen()),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.register,
          builder: (_, __) => const RegisterScreen(),
        ),

        // ── Phone auth ────────────────────────────────────────────
        GoRoute(
          path: AppRoutes.phoneRegister,
          builder: (_, __) => const RegisterScreen(),
        ),
        GoRoute(
          path: AppRoutes.phoneLogin,
          builder: (_, __) => const LoginScreen(),
        ),

        // ── Deep link: child joins via invite ─────────────────────
        GoRoute(
          path: AppRoutes.joinInvite,
          builder: (context, state) {
            final token = state.uri.queryParameters['token'] ?? '';
            return JoinScreen(token: token);
          },
        ),

        // ── Parent screens (full screen, outside shell) ───────────
        GoRoute(
          path: AppRoutes.parentDashboard,
          builder: (_, __) => const ParentDashboardScreen(),
        ),
        GoRoute(
          path: '${AppRoutes.parentChildDetail}/:childId',
          builder: (context, state) => ChildProgressDetailScreen(
            childId: int.parse(state.pathParameters['childId']!),
          ),
        ),
        GoRoute(
          path: AppRoutes.inviteLinks,
          builder: (_, __) => const InviteLinksScreen(),
        ),

        // ── Main shell with bottom nav (child experience) ─────────
        ShellRoute(
          builder: (context, state, child) => _MainShell(
            child: child,
            location: state.matchedLocation,
          ),
          routes: [
            GoRoute(path: AppRoutes.home, builder: (_, __) => HomeScreen()),
            GoRoute(
                path: AppRoutes.progress,
                builder: (_, __) => const ProgressScreen()),
            GoRoute(
                path: AppRoutes.spellingBee,
                builder: (_, __) => const SpellingBeeScreen()),
            GoRoute(
                path: AppRoutes.profile,
                builder: (_, __) => const ProfileScreen()),
          ],
        ),

        // ── Lessons (full screen, outside shell) ──────────────────
        GoRoute(
          path: AppRoutes.lessons,
          builder: (_, __) => const LessonsListScreen(),
          routes: [
            GoRoute(
              path: ':lessonId',
              builder: (context, state) => PhonemeLessonScreen(
                lessonId: int.parse(state.pathParameters['lessonId']!),
              ),
              routes: [
                GoRoute(
                  path: 'exercise/:exerciseId',
                  builder: (context, state) {
                    final extra = state.extra as Map<String, dynamic>? ?? {};
                    return PronunciationScreen(
                      exerciseId:
                          int.parse(state.pathParameters['exerciseId']!),
                      exerciseContent: extra['content'] as String? ?? '',
                      exerciseType: extra['type'] as String? ?? 'WORD',
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.spellingBeeGame,
          builder: (_, __) => const SpellingBeeScreen(),
        ),
      ];
}

// ── Bottom nav shell ───────────────────────────────────────────────
class _MainShell extends StatelessWidget {
  final Widget child;
  final String location;
  const _MainShell({required this.child, required this.location});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: _BottomNav(location: location),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final String location;
  const _BottomNav({required this.location});

  @override
  Widget build(BuildContext context) {
    final items = [
      (icon: Icons.home_rounded, label: 'Home', route: AppRoutes.home),
      (
        icon: Icons.bar_chart_rounded,
        label: 'Progress',
        route: AppRoutes.progress
      ),
      (
        icon: Icons.stars_rounded,
        label: 'Spelling',
        route: AppRoutes.spellingBee
      ),
      (icon: Icons.person_rounded, label: 'Me', route: AppRoutes.profile),
    ];

    int idx = items.indexWhere((i) => location.startsWith(i.route));
    if (idx < 0) idx = 0;

    return NavigationBar(
      selectedIndex: idx,
      onDestinationSelected: (i) => context.go(items[i].route),
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFFF6B6B).withOpacity(0.15),
      destinations: items
          .map((i) => NavigationDestination(icon: Icon(i.icon), label: i.label))
          .toList(),
    );
  }
}

// ── Deep link handler ──────────────────────────────────────────────
/// Wire in main.dart after router creation:
///   DeepLinkHandler(appRouter.router);
///
/// Requires: flutter pub add app_links
/// Once added, uncomment the app_links import below and remove the stub.
class DeepLinkHandler {
  final GoRouter router;

  DeepLinkHandler(this.router) {
    _init();
  }

  Future<void> _init() async {
    // ── Uncomment after: flutter pub add app_links ────────────
    // import 'package:app_links/app_links.dart';
    //
    // final appLinks = AppLinks();
    // try {
    //   final initialUri = await appLinks.getInitialLink();
    //   if (initialUri != null) _handleLink(initialUri);
    // } catch (_) {}
    // appLinks.uriLinkStream.listen(_handleLink, onError: (_) {});
  }

  // ignore: unused_element
  void _handleLink(Uri uri) {
    if (uri.scheme == DeepLinkConstants.scheme &&
        uri.path == DeepLinkConstants.joinPath) {
      final token = DeepLinkConstants.parseToken(uri);
      if (token != null && token.isNotEmpty) {
        router.go('${AppRoutes.joinInvite}?token=$token');
      }
    }
  }
}
