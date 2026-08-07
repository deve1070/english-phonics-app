import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../router/app_routes.dart';
import 'learning_cursor.dart';

/// The things a child does in a day, in the order they are handed over.
///
/// Not a menu. The child never sees this list and never picks from it —
/// each one arrives when the one before it is finished, which is the whole
/// difference between an app that teaches and an app that asks a
/// five-year-old to plan their own lesson.
enum DayActivity {
  /// The new sound: how it is written, saying it, and words that use it.
  lesson,

  /// The listening game. Second because it tests sounds already met, and
  /// because it needs no microphone — it is the one activity that still
  /// works when the connection does not.
  findTheSound,

  /// Building words from letters. Last: it leans on both of the above.
  spellingBee,
}

/// The order, and nothing else.
///
/// Pure on purpose. Everything about *what comes next* is decided here,
/// with no storage, no clock and no navigator in the way, so the sequence
/// can be checked in a test rather than by playing through a day.
abstract class DayPlan {
  static const List<DayActivity> order = [
    DayActivity.lesson,
    DayActivity.findTheSound,
    DayActivity.spellingBee,
  ];

  /// The first thing in [order] that is not finished, or null when the day
  /// is done.
  ///
  /// Null is a real answer, not a failure: a day that ends is the point.
  /// Without it the app would hand out a fourth activity, and a fifth, and
  /// a child would learn that it never lets them go.
  static DayActivity? next(Set<DayActivity> done) {
    for (final activity in order) {
      if (!done.contains(activity)) return activity;
    }
    return null;
  }
}

/// Plays the day.
///
/// Two questions, and they are the same question: *where does this child
/// go now* — asked at launch, and asked again each time an activity
/// finishes. The answer is always a route, so no caller has to know what
/// the plan holds or how far through it the child is.
///
/// What is finished is stored against a date. Reading it on a different
/// date returns nothing, so a new day starts a fresh plan without anything
/// having to run at midnight.
class DayRunner {
  static const _key = 'day_plan';

  final CursorStore _cursor;
  final DateTime Function() _now;

  DayRunner(this._cursor, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// Local date, not UTC. The day has to turn over when the child's day
  /// does — a bedtime session in Addis must not be counted as tomorrow.
  String _today() {
    final d = _now();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// What today's plan already holds. Never throws: this is on the launch
  /// path, and an unreadable plan means "nothing done yet", which costs a
  /// child a repeat and not a screen they cannot get past.
  Future<Set<DayActivity>> doneToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return {};

      final json = jsonDecode(raw);
      if (json is! Map) return {};
      if (json['date'] != _today()) return {}; // yesterday's plan

      final names = json['done'];
      if (names is! List) return {};
      return {
        for (final activity in DayActivity.values)
          if (names.contains(activity.name)) activity,
      };
    } catch (_) {
      return {};
    }
  }

  /// Records [finished] and answers with where the child goes next.
  ///
  /// Safe to call twice for the same activity — a set, not a tally. A
  /// child who replays Find the Sound has not skipped ahead to the end of
  /// their day.
  Future<String> advance(DayActivity finished) async {
    final done = await doneToday()..add(finished);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'date': _today(),
          'done': [for (final a in done) a.name],
        }),
      );
    } catch (_) {
      // Unwritable storage costs the child a repeat of this activity on
      // the next launch. It must not cost them the next one.
    }
    return routeFor(DayPlan.next(done));
  }

  /// Where a child goes when they open the app.
  Future<String> openingRoute() async => routeFor(DayPlan.next(await doneToday()));

  /// The route that plays [activity], or the day's ending when it is null.
  Future<String> routeFor(DayActivity? activity) async {
    switch (activity) {
      case null:
        return AppRoutes.todayDone;

      case DayActivity.lesson:
        // Mid-lesson, so pick up at the exact step. With no cursor there is
        // nothing to resume — a first launch, or a child who has just
        // finished the curriculum — and Home is where the path is shown.
        final cursor = await _cursor.read();
        return cursor?.routeUnder(AppRoutes.lessons) ?? AppRoutes.home;

      case DayActivity.findTheSound:
        return AppRoutes.recognition;

      case DayActivity.spellingBee:
        return AppRoutes.spellingBee;
    }
  }

  /// On logout, so the next child on this device starts their own day
  /// rather than inheriting how much of one a sibling has already done.
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
