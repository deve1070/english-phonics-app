import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import 'engagement_models.dart';

/// Reads the child's quest, streak, collection and story shelf.
///
/// Every method degrades to an empty value rather than throwing. These
/// surfaces are decoration around the lesson path: a child whose network
/// dropped should see a home screen with no quest card on it, not an
/// error page instead of their lessons. The one exception is
/// [markCollectionSeen] — if acknowledging fails the celebration simply
/// plays again next time, which is the right way to fail.
class EngagementRemoteDataSource {
  final Dio _dio;
  EngagementRemoteDataSource(this._dio);

  Future<DailyQuest> getTodaysQuest() async {
    try {
      final response = await _dio.get(ApiConstants.questToday);
      return DailyQuest.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      return DailyQuest.empty;
    }
  }

  Future<StreakInfo> getStreak() async {
    try {
      final response = await _dio.get(ApiConstants.myStreak);
      return StreakInfo.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      return StreakInfo.none;
    }
  }

  Future<Collection> getCollection() async {
    final response = await _dio.get(ApiConstants.myCollection);
    return Collection.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> markCollectionSeen() async {
    try {
      await _dio.post(ApiConstants.collectionSeen);
    } on DioException {
      // The unlock stays pending and the child is congratulated again on
      // their next visit. Harmless, and better than an error over a
      // celebration.
    }
  }

  /// This week's promise, or the three the child may choose from.
  ///
  /// One call for both states, so the home screen never has to ask
  /// "has this child chosen yet?" before it knows what to draw.
  Future<WeeklyGoal> getGoal() async {
    try {
      final response = await _dio.get(ApiConstants.myGoal);
      return WeeklyGoal.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      return WeeklyGoal.none;
    }
  }

  /// Make the promise. The size comes back from the server, which is
  /// where it is worked out from this child's own recent weeks.
  Future<WeeklyGoal> chooseGoal(GoalKind kind) async {
    final response = await _dio.post(
      ApiConstants.myGoal,
      data: {'kind': kind.wire},
    );
    return WeeklyGoal.fromJson(response.data as Map<String, dynamic>);
  }

  /// A short round of "which symbol says this sound?".
  ///
  /// Throws rather than degrading: this one is the activity itself, not
  /// decoration around it, and a child handed an empty game would have
  /// nothing to do and no idea why.
  Future<RecognitionRound> getRecognitionRound({
    required RecognitionMode mode,
  }) async {
    final response = await _dio.get(
      ApiConstants.recognitionRound,
      queryParameters: {'mode': mode.wire},
    );
    return RecognitionRound.fromJson(response.data as Map<String, dynamic>);
  }

  /// Post a finished round in one write. Called after the child has
  /// already seen every result, so a failure here costs the record and
  /// not the experience.
  Future<RecognitionSummary> submitRecognitionRound({
    required RecognitionMode mode,
    required List<RecognitionAnswer> answers,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.recognitionRound,
        data: {
          'mode': mode.wire,
          'answers': answers.map((a) => a.toJson()).toList(),
        },
      );
      return RecognitionSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      // The round is lost to the record. The child keeps the round they
      // just played, which is the part that mattered to them.
      return RecognitionSummary.none;
    }
  }

  Future<StoryShelf> getStories() async {
    final response = await _dio.get(ApiConstants.myStories);
    return StoryShelf.fromJson(response.data as Map<String, dynamic>);
  }
}
