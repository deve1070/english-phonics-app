import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Where a child had got to.
@immutable
class LearningCursor {
  final int lessonId;
  final int? phonemeId;

  /// A step within the phoneme, named by the lesson screen that owns the
  /// steps. Not an enum here either: the store has no opinion about the
  /// value and hands back whatever it was given, so adding a step is a
  /// change to one screen rather than to the whole chain.
  final String stage;

  const LearningCursor({
    required this.lessonId,
    this.phonemeId,
    required this.stage,
  });

  Map<String, dynamic> toJson() => {
        'lesson_id': lessonId,
        'phoneme_id': phonemeId,
        'stage': stage,
      };

  static LearningCursor? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final lessonId = json['lesson_id'];
    final stage = json['stage'];
    if (lessonId is! int || stage is! String || stage.isEmpty) return null;
    return LearningCursor(
      lessonId: lessonId,
      phonemeId: json['phoneme_id'] as int?,
      stage: stage,
    );
  }

  /// The route that puts a child back here.
  ///
  /// Lives on the cursor, and takes the lessons path rather than importing
  /// it, so the one place that builds this URL and the one place that
  /// reads it back can be checked against each other in a test. They are
  /// in different files and only ever meet at launch, which is the worst
  /// possible moment to discover they disagree.
  String routeUnder(String lessonsPath) => Uri(
        path: '$lessonsPath/$lessonId',
        queryParameters: {
          if (phonemeId != null) 'phoneme': '$phonemeId',
          'stage': stage,
        },
      ).toString();

  @override
  bool operator ==(Object other) =>
      other is LearningCursor &&
      other.lessonId == lessonId &&
      other.phonemeId == phonemeId &&
      other.stage == stage;

  @override
  int get hashCode => Object.hash(lessonId, phonemeId, stage);

  @override
  String toString() => 'LearningCursor($lessonId, $phonemeId, $stage)';
}

/// Keeps the cursor on the device and on the server, and prefers the
/// device.
///
/// The device copy is what launch reads. It is there in microseconds and
/// it is there on a train, and the alternative — waiting on a request
/// before deciding which screen to show — means a child opening the app on
/// a bad connection watches a spinner to find out where they already were.
///
/// The server copy exists for the case the device cannot cover: a
/// reinstall, a new phone, a shared family device. It is written after the
/// local one and its failure is swallowed, because a child moving from one
/// step to the next must not be made to wait for, or be told about, a
/// network round trip they did not ask for.
class CursorStore {
  static const _key = 'learning_cursor';

  final Dio _dio;
  CursorStore(this._dio);

  /// Guards against a slow write racing a fast one. Stage changes can come
  /// a second apart, and without this the loser of two in-flight requests
  /// could be the newer position.
  int _writeSeq = 0;

  /// The device's copy. Never throws: a launch decision cannot depend on
  /// storage behaving.
  Future<LearningCursor?> readLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      return LearningCursor.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// The server's copy, or null. Short timeout on purpose — this is only
  /// consulted when the device has nothing, and a child staring at a
  /// splash screen is worse than a child starting from the beginning.
  Future<LearningCursor?> readRemote({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final res = await _dio
          .get(ApiConstants.myCursor)
          .timeout(timeout);
      final data = res.data;
      if (data is! Map) return null;
      return LearningCursor.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }

  /// What launch should act on: the device first, the server only if the
  /// device has nothing to say.
  Future<LearningCursor?> read() async =>
      await readLocal() ?? await readRemote();

  /// Records a position. Returns as soon as the device copy is written.
  Future<void> save(LearningCursor cursor) async {
    final seq = ++_writeSeq;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(cursor.toJson()));
    } catch (_) {
      // A cursor that cannot be stored locally is still worth sending.
    }
    unawaited(_pushRemote(cursor, seq));
  }

  Future<void> _pushRemote(LearningCursor cursor, int seq) async {
    // Superseded before this one got out. Sending it would race the newer
    // position and could leave the server holding the older of the two.
    if (seq != _writeSeq) return;
    try {
      await _dio.put(ApiConstants.myCursor, data: cursor.toJson());
    } catch (_) {
      // Offline, or the server said no. The device copy already holds the
      // position, and the next step will try again.
    }
  }

  /// On logout, so the next child on this device does not resume into
  /// somebody else's lesson.
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
