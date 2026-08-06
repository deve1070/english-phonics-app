// Which screens sit inside the bottom-nav shell.
//
// A screen inside the shell keeps the nav bar on top of it. Spelling Bee
// was in there, so a child halfway through spelling a word had Home and
// Progress sitting under their thumb; one tap and the word was gone. A
// screen that is a task should offer no way out but finishing it.
//
// This reads the route table rather than the pixels, because that is where
// the mistake was: nothing looked wrong in the shell's own code.
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:phonics_app/core/network/token_storage.dart';
import 'package:phonics_app/core/router/app_router.dart';
import 'package:phonics_app/core/router/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Paths of the routes nested inside the ShellRoute.
Set<String> shellPaths(GoRouter router) {
  final shell = router.configuration.routes
      .expand((r) => r is ShellRoute ? [r] : <ShellRoute>[])
      .single;
  return shell.routes.whereType<GoRoute>().map((r) => r.path).toSet();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late GoRouter router;

  setUp(() {
    router = AppRouter(TokenStorage()).router;
  });

  test('the shell holds two tabs and nothing else', () {
    expect(
      shellPaths(router),
      {AppRoutes.home, AppRoutes.profile},
    );
  });

  test('a task screen is never inside the shell', () {
    // Each of these is something a child is in the middle of doing.
    for (final task in [
      AppRoutes.spellingBee,
      AppRoutes.spellingBeeGame,
      AppRoutes.recognition,
      AppRoutes.practice,
    ]) {
      expect(
        shellPaths(router),
        isNot(contains(task)),
        reason: '$task would keep the nav bar over a child mid-task',
      );
    }
  });

  test('progress is reachable, but not as a tab', () {
    expect(shellPaths(router), isNot(contains(AppRoutes.progress)));
    final top = router.configuration.routes
        .whereType<GoRoute>()
        .map((r) => r.path)
        .toSet();
    expect(top, contains(AppRoutes.progress));
    expect(top, contains(AppRoutes.spellingBee));
  });
}
