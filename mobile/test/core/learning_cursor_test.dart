// The stored position a child is put back to at launch.
//
// Its failures all have the same shape and the same cost: a child sent to
// the wrong place, on every launch, with no way to correct it — they
// cannot navigate, which is the whole reason the cursor exists.
//
// So the cases here are the ugly ones. Storage that fails, a payload from
// a server that has changed, a stage name this build has never heard of.
// Each has to end somewhere a child can carry on from.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonics_app/core/session/learning_cursor.dart';
import 'package:shared_preferences/shared_preferences.dart';

CursorStore storeWith(Dio dio) => CursorStore(dio);

Dio deadDio() {
  // Points nowhere and fails fast: every remote call in these tests is
  // meant to fail, because what is being checked is that failing remotely
  // never costs the local answer.
  final dio = Dio(BaseOptions(
    baseUrl: 'http://127.0.0.1:1',
    connectTimeout: const Duration(milliseconds: 40),
    receiveTimeout: const Duration(milliseconds: 40),
  ));
  return dio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('reading a cursor back', () {
    test('what was saved is what is read', () async {
      final store = storeWith(deadDio());
      await store.save(const LearningCursor(
          lessonId: 7, phonemeId: 42, stage: 'gate'));

      expect(
        await store.readLocal(),
        const LearningCursor(lessonId: 7, phonemeId: 42, stage: 'gate'),
      );
    });

    test('a phoneme is optional', () async {
      final store = storeWith(deadDio());
      await store.save(const LearningCursor(lessonId: 3, stage: 'quiz'));
      final read = await store.readLocal();
      expect(read?.lessonId, 3);
      expect(read?.phonemeId, isNull);
    });

    test('a child who has never started has no cursor', () async {
      expect(await storeWith(deadDio()).readLocal(), isNull);
    });

    test('saving twice keeps the newer position', () async {
      final store = storeWith(deadDio());
      await store.save(const LearningCursor(lessonId: 1, stage: 'phonemeIntro'));
      await store.save(const LearningCursor(lessonId: 2, stage: 'exercises'));
      expect((await store.readLocal())?.lessonId, 2);
    });
  });

  group('when the server cannot be reached', () {
    test('saving still works and does not throw', () async {
      final store = storeWith(deadDio());
      await expectLater(
        store.save(const LearningCursor(lessonId: 5, stage: 'gate')),
        completes,
      );
      expect((await store.readLocal())?.lessonId, 5);
    });

    test('reading falls back to the device', () async {
      final store = storeWith(deadDio());
      await store.save(const LearningCursor(lessonId: 9, stage: 'quiz'));
      expect((await store.read())?.lessonId, 9);
    });

    test('reading with nothing stored gives null, not an error', () async {
      await expectLater(storeWith(deadDio()).read(), completion(isNull));
    });
  });

  group('rubbish in storage', () {
    // A half-written value, or one from a build that stored something
    // else. Launch has to survive it.
    test('unparseable json reads as no cursor', () async {
      SharedPreferences.setMockInitialValues(
          {'learning_cursor': 'not json at all'});
      expect(await storeWith(deadDio()).readLocal(), isNull);
    });

    test('json missing the lesson reads as no cursor', () async {
      SharedPreferences.setMockInitialValues(
          {'learning_cursor': '{"stage":"gate"}'});
      expect(await storeWith(deadDio()).readLocal(), isNull);
    });

    test('a lesson id of the wrong type reads as no cursor', () async {
      SharedPreferences.setMockInitialValues(
          {'learning_cursor': '{"lesson_id":"seven","stage":"gate"}'});
      expect(await storeWith(deadDio()).readLocal(), isNull);
    });

    test('an empty stage reads as no cursor', () async {
      // Better to start the lesson than to route to a stage of "".
      SharedPreferences.setMockInitialValues(
          {'learning_cursor': '{"lesson_id":4,"stage":""}'});
      expect(await storeWith(deadDio()).readLocal(), isNull);
    });
  });

  group('clearing', () {
    test('logging out leaves nothing to resume into', () async {
      // The position lives on the device, not in the token, so signing out
      // does not remove it on its own. A sibling signing in next would
      // otherwise land in the middle of someone else's lesson.
      final store = storeWith(deadDio());
      await store.save(const LearningCursor(lessonId: 8, stage: 'gate'));
      await store.clear();
      expect(await store.readLocal(), isNull);
    });
  });

  routeRoundTrip();

  group('parsing what the server sends', () {
    test('a null body is no cursor', () {
      expect(LearningCursor.fromJson(null), isNull);
    });

    test('a well-formed body parses', () {
      final c = LearningCursor.fromJson(const {
        'lesson_id': 12,
        'phoneme_id': 30,
        'stage': 'exercises',
        'updated_at': '2026-08-06T10:00:00Z',
      });
      expect(c, const LearningCursor(
          lessonId: 12, phonemeId: 30, stage: 'exercises'));
    });
  });
}

// The URL that carries the position from launch to the lesson screen.
//
// The splash builds it and the router takes it apart, in different files,
// meeting only at launch — the worst moment to find out they disagree.
// Parsing here mirrors app_router.dart exactly.
LearningCursor? parseAsRouterDoes(String url) {
  final uri = Uri.parse(url);
  final lessonId = int.tryParse(uri.pathSegments.last);
  if (lessonId == null) return null;
  return LearningCursor(
    lessonId: lessonId,
    phonemeId: int.tryParse(uri.queryParameters['phoneme'] ?? ''),
    stage: uri.queryParameters['stage'] ?? '',
  );
}

void routeRoundTrip() {
  group('the resume URL survives the round trip', () {
    for (final cursor in const [
      LearningCursor(lessonId: 1, phonemeId: 2, stage: 'phonemeIntro'),
      LearningCursor(lessonId: 18, phonemeId: 90, stage: 'exercises'),
      LearningCursor(lessonId: 4, stage: 'gate'),
    ]) {
      test('$cursor', () {
        expect(parseAsRouterDoes(cursor.routeUnder('/lessons')), cursor);
      });
    }

    test('it is nested under the lessons path', () {
      const c = LearningCursor(lessonId: 6, phonemeId: 7, stage: 'quiz');
      expect(c.routeUnder('/lessons'), startsWith('/lessons/6?'));
    });

    test('a missing phoneme is left out rather than sent as "null"', () {
      const c = LearningCursor(lessonId: 6, stage: 'quiz');
      expect(c.routeUnder('/lessons'), isNot(contains('phoneme')));
      expect(parseAsRouterDoes(c.routeUnder('/lessons'))?.phonemeId, isNull);
    });
  });
}
