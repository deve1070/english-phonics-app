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
// NEW: engagement — collectibles and the decodable story shelf
import '../../features/engagement/presentation/screens/collection_screen.dart';
import '../../features/engagement/presentation/screens/goal_screen.dart';
import '../../features/engagement/presentation/screens/recognition_screen.dart';
import '../../features/engagement/presentation/screens/story_shelf_screen.dart';
// NEW: phone auth screens
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
// NEW: join screen (child redeems invite link)
import '../../features/home/presentation/screens/join_screen.dart';
// NEW: parent screens
import '../../features/parent/presentation/screens/parent_dashboard_screen.dart';
import '../../features/parent/presentation/screens/child_progress_detail_screen.dart';
import '../../features/parent/presentation/screens/invite_links_screen.dart';
import '../../features/parent/presentation/screens/promise_screen.dart';

class AppRouter {
  final TokenStorage tokenStorage;

  AppRouter(this.tokenStorage);

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    redirect: _guard,
    routes: _routes,
  );

  // ── Route guard ───────────────────────────────────────────────
  Future<String?> _guard(BuildContext context, GoRouterState state) async {
    final location = state.matchedLocation;
    
    // Always allow public routes
    const publicPaths = {
      AppRoutes.splash,
      AppRoutes.onboarding,
      AppRoutes.phoneLogin,
      AppRoutes.phoneRegister,
      AppRoutes.joinInvite,
    };

    if (publicPaths.contains(location)) {
        // Prevent authenticated users from going to login again
        if (location == AppRoutes.phoneLogin) {
            final isAuthenticated = await tokenStorage.hasValidToken();
            if (isAuthenticated) {
                final role = await tokenStorage.getUserRole();
                if (role == 'PARENT') return AppRoutes.parentDashboard;
                if (role == 'STUDENT') return AppRoutes.home;
            }
        }
        return null;
    }

    final isAuthenticated = await tokenStorage.hasValidToken();
    if (!isAuthenticated) {
      // Students and parents must be registered/logged in to access any protected material.
      return AppRoutes.phoneLogin;
    }

    // Determine if this is a parent-only route
    final isParentRoute = location.startsWith(AppRoutes.parentDashboard) ||
                          location.startsWith(AppRoutes.inviteLinks) ||
                          location.startsWith(AppRoutes.parentPromise);

    if (isParentRoute) {
      final role = await tokenStorage.getUserRole();
      if (role != 'PARENT') {
        return AppRoutes.phoneLogin;
      }
    }
    
    // Prevent parents from accessing child-only routes
    if (_isChildOnlyRoute(location)) {
      final role = await tokenStorage.getUserRole();
      if (role == 'PARENT') {
        return AppRoutes.parentDashboard;
      }
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
        GoRoute(
          path: '${AppRoutes.parentPromise}/:childId',
          builder: (context, state) => PromiseScreen(
            childId: int.parse(state.pathParameters['childId']!),
          ),
        ),

        // ── Main shell with bottom nav (child experience) ─────────
        ShellRoute(
          builder: (context, state, child) => _MainShell(
            child: child,
            location: state.matchedLocation,
          ),
          // Two tabs, and only screens a child may wander between.
          //
          // Progress and Spelling Bee used to sit here as tabs of their
          // own. Spelling Bee runs its game inside its own screen, so the
          // nav bar stayed on-screen throughout: a child halfway through
          // spelling a word could tap Home and lose it. A screen that is a
          // task should offer no way out but finishing. Both are now
          // full-screen routes below.
          routes: [
            GoRoute(path: AppRoutes.home, builder: (_, __) => HomeScreen()),
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
              // The resume position rides in the query string rather than
              // in `extra`: it survives a restart, it shows up in a log
              // when a child lands somewhere odd, and it is the same
              // whether the route came from the splash or from a tap.
              builder: (context, state) => PhonemeLessonScreen(
                lessonId: int.parse(state.pathParameters['lessonId']!),
                resumePhonemeId:
                    int.tryParse(state.uri.queryParameters['phoneme'] ?? ''),
                resumeStage: state.uri.queryParameters['stage'],
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
        // ── Engagement (full screen, outside shell) ───────────────
        GoRoute(
          path: AppRoutes.collection,
          builder: (_, __) => const CollectionScreen(),
        ),
        GoRoute(
          path: AppRoutes.stories,
          builder: (_, __) => const StoryShelfScreen(),
        ),
        GoRoute(
          path: AppRoutes.recognition,
          builder: (_, __) => const RecognitionScreen(),
        ),
        GoRoute(
          path: AppRoutes.goal,
          builder: (_, __) => const GoalScreen(),
        ),
        GoRoute(
          // Practise a single exercise with no lesson context. See
          // AppRoutes.practice for why this exists alongside the nested
          // lesson route.
          path: '${AppRoutes.practice}/:exerciseId',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return PronunciationScreen(
              exerciseId: int.parse(state.pathParameters['exerciseId']!),
              exerciseContent: extra['content'] as String? ?? '',
              exerciseType: extra['type'] as String? ?? 'WORD',
            );
          },
        ),
        GoRoute(
          path: AppRoutes.spellingBee,
          builder: (_, __) => const SpellingBeeScreen(),
        ),
        GoRoute(
          path: AppRoutes.spellingBeeGame,
          builder: (_, __) => const SpellingBeeScreen(),
        ),
        GoRoute(
          path: AppRoutes.progress,
          builder: (_, __) => const ProgressScreen(),
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
    // Two. Four tabs is four decisions to make before any learning starts,
    // and three of them led away from it.
    final items = [
      (icon: Icons.home_rounded, label: 'Home', route: AppRoutes.home),
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
