// The sequence the app plays, and the day it plays it in.
//
// A child never chooses what to do next here — the runner decides, and it
// decides at launch and after every activity. So its failures are not "a
// button went to the wrong screen"; they are a child handed the same work
// twice, or dropped somewhere with nothing to do, or never let go of.
//
// Three things are worth pinning hardest: the order, the ending, and the
// day boundary.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/core/router/app_routes.dart';
import 'package:phonics_app/core/session/day_plan.dart';
import 'package:phonics_app/core/session/learning_cursor.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Points nowhere and fails fast. Nothing here should ever need the
/// network to decide where a child goes.
Dio deadDio() => Dio(BaseOptions(
      baseUrl: 'http://127.0.0.1:1',
      connectTimeout: const Duration(milliseconds: 40),
      receiveTimeout: const Duration(milliseconds: 40),
    ));

DayRunner runnerAt(DateTime day, {CursorStore? cursor}) => DayRunner(
      cursor ?? CursorStore(deadDio()),
      now: () => day,
    );

final monday = DateTime(2026, 8, 3, 9, 0);
final tuesday = DateTime(2026, 8, 4, 9, 0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the order', () {
    test('nothing done yet means the lesson', () {
      expect(DayPlan.next({}), DayActivity.lesson);
    });

    test('the lesson leads to the listening game', () {
      expect(DayPlan.next({DayActivity.lesson}), DayActivity.findTheSound);
    });

    test('the listening game leads to spelling', () {
      expect(
        DayPlan.next({DayActivity.lesson, DayActivity.findTheSound}),
        DayActivity.spellingBee,
      );
    });

    test('everything done means the day is over', () {
      expect(DayPlan.next(DayActivity.values.toSet()), isNull);
    });

    test('an activity done out of order is not offered again', () {
      // A child could reach Find the Sound first if the day were resumed
      // oddly. The plan is a set of what is finished, not a cursor into a
      // list, so the lesson is still what comes next.
      expect(DayPlan.next({DayActivity.findTheSound}), DayActivity.lesson);
    });
  });

  group('playing through a day', () {
    test('each activity hands over to the next, and then it ends', () async {
      final runner = runnerAt(monday);

      expect(await runner.advance(DayActivity.lesson), AppRoutes.recognition);
      expect(
          await runner.advance(DayActivity.findTheSound),
          AppRoutes.spellingBee);
      expect(
          await runner.advance(DayActivity.spellingBee), AppRoutes.todayDone);
    });

    test('finishing an activity twice does not skip the next one', () async {
      // Replaying Find the Sound must not cost the child their spelling
      // game — done is a set, not a tally.
      final runner = runnerAt(monday);
      await runner.advance(DayActivity.lesson);
      await runner.advance(DayActivity.findTheSound);

      expect(
          await runner.advance(DayActivity.findTheSound),
          AppRoutes.spellingBee);
    });
  });

  group('reopening the app', () {
    test('a child who has done nothing starts at the lesson', () async {
      // No cursor yet, so the lesson step has nowhere to resume to and
      // Home is where the path is shown.
      expect(await runnerAt(monday).openingRoute(), AppRoutes.home);
    });

    test('mid-day, it picks up at the activity still outstanding', () async {
      await runnerAt(monday).advance(DayActivity.lesson);
      expect(await runnerAt(monday).openingRoute(), AppRoutes.recognition);
    });

    test('a finished day stays finished', () async {
      // The stop has to survive a relaunch. Otherwise closing and
      // reopening the app is a way to be handed more work, which is
      // exactly the loop this screen exists to break.
      final runner = runnerAt(monday);
      for (final activity in DayActivity.values) {
        await runner.advance(activity);
      }
      expect(await runnerAt(monday).openingRoute(), AppRoutes.todayDone);
    });
  });

  group('the day boundary', () {
    test('tomorrow is a fresh plan', () async {
      final runner = runnerAt(monday);
      for (final activity in DayActivity.values) {
        await runner.advance(activity);
      }

      expect(await runnerAt(tuesday).doneToday(), isEmpty);
      expect(await runnerAt(tuesday).openingRoute(), AppRoutes.home);
    });

    test('the same day at a different hour is the same plan', () async {
      await runnerAt(DateTime(2026, 8, 3, 7, 30)).advance(DayActivity.lesson);
      expect(
        await runnerAt(DateTime(2026, 8, 3, 20, 45)).doneToday(),
        {DayActivity.lesson},
      );
    });

    test('the plan is keyed by the clock it is given, not by UTC', () async {
      // The runner reads the calendar fields of whatever clock it is
      // handed, and the app hands it DateTime.now() — a local one. That
      // matters here: Addis is UTC+3, so an evening session is already
      // tomorrow in UTC, and keying on UTC would wipe a child's day out
      // from under them mid-sitting.
      //
      // Asserted against the stored key rather than through a second read,
      // because a wrong-but-consistent key would pass a read-back.
      await runnerAt(DateTime(2026, 8, 3, 21, 30)).advance(DayActivity.lesson);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('day_plan'), contains('"date":"2026-08-03"'));
    });

    test('single-digit months and days are padded', () async {
      // The date is compared as a string, so 2026-8-3 and 2026-08-03 would
      // be different days.
      await runnerAt(DateTime(2026, 1, 9)).advance(DayActivity.lesson);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('day_plan'), contains('"date":"2026-01-09"'));
    });
  });

  group('the lesson step', () {
    test('resumes the exact position when there is one', () async {
      final cursor = CursorStore(deadDio());
      await cursor.save(
          const LearningCursor(lessonId: 7, phonemeId: 42, stage: 'gate'));

      final route = await runnerAt(monday, cursor: cursor).openingRoute();
      expect(route, startsWith('${AppRoutes.lessons}/7?'));
      expect(route, contains('phoneme=42'));
      expect(route, contains('stage=gate'));
    });

    test('falls back to Home when there is nothing to resume', () async {
      // The end of the curriculum, or a first launch. Either way there is
      // no lesson to reopen and Home is not a dead end.
      expect(
        await runnerAt(monday).routeFor(DayActivity.lesson),
        AppRoutes.home,
      );
    });
  });

  group('storage that cannot be trusted', () {
    test('rubbish reads as a fresh day rather than throwing', () async {
      // This runs on the launch path. An unreadable plan costs a child a
      // repeat; an exception costs them the app.
      SharedPreferences.setMockInitialValues({'day_plan': 'not json'});
      expect(await runnerAt(monday).doneToday(), isEmpty);
    });

    test('a plan with no date is not trusted to be today', () async {
      SharedPreferences.setMockInitialValues({
        'day_plan': '{"done":["lesson","findTheSound","spellingBee"]}'
      });
      expect(await runnerAt(monday).doneToday(), isEmpty);
    });

    test('an activity name this build does not know is ignored', () async {
      // A renamed or removed activity must not take the rest of the plan
      // with it.
      SharedPreferences.setMockInitialValues({
        'day_plan': '{"date":"2026-08-03","done":["lesson","tracing"]}'
      });
      expect(await runnerAt(monday).doneToday(), {DayActivity.lesson});
    });

    test('done as the wrong type reads as a fresh day', () async {
      SharedPreferences.setMockInitialValues(
          {'day_plan': '{"date":"2026-08-03","done":"lesson"}'});
      expect(await runnerAt(monday).doneToday(), isEmpty);
    });
  });

  group('clearing', () {
    test('logging out leaves the next child a whole day', () async {
      // A sibling signing in on the same phone must not be told their day
      // is nearly over.
      final runner = runnerAt(monday);
      await runner.advance(DayActivity.lesson);
      await runner.clear();

      expect(await runner.doneToday(), isEmpty);
    });
  });
}
