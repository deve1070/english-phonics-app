/// Wire types for the child's own engagement view.
///
/// Deliberately thin. These carry what the server decided — what is
/// unlocked, what is done, how long the run is — and nothing derived.
/// Every rule (what counts as mastery, when a freeze is spent, which
/// three exercises today holds) lives on the server, so two clients can
/// never disagree about a child's progress and an old app cannot award
/// itself stickers.
library;

enum QuestSlot { review, current, stretch }

QuestSlot _slotFrom(String raw) => switch (raw) {
      'review' => QuestSlot.review,
      'stretch' => QuestSlot.stretch,
      _ => QuestSlot.current,
    };

extension QuestSlotLabel on QuestSlot {
  /// What the child is told the task is for.
  ///
  /// Never "your weakest sound" or anything that names a deficit — the
  /// review slot exists because that sound is worth another go, and a
  /// six-year-old does not need to be told it is because they are bad
  /// at it.
  String get label => switch (this) {
        QuestSlot.review => 'Say it again',
        QuestSlot.current => "Today's sound",
        QuestSlot.stretch => 'Something new',
      };
}

class QuestItem {
  final QuestSlot slot;
  final int exerciseId;
  final String content;
  final String type;
  final bool completed;

  const QuestItem({
    required this.slot,
    required this.exerciseId,
    required this.content,
    required this.type,
    required this.completed,
  });

  factory QuestItem.fromJson(Map<String, dynamic> json) => QuestItem(
        slot: _slotFrom(json['slot'] as String),
        exerciseId: json['exercise_id'] as int,
        content: json['content'] as String,
        type: json['type'] as String? ?? 'word',
        completed: json['completed'] as bool? ?? false,
      );
}

class DailyQuest {
  final List<QuestItem> items;
  final int completedCount;
  final bool isComplete;

  const DailyQuest({
    required this.items,
    required this.completedCount,
    required this.isComplete,
  });

  /// The server sends fewer than three when the curriculum cannot fill a
  /// slot, so nothing here may assume three.
  bool get isEmpty => items.isEmpty;

  factory DailyQuest.fromJson(Map<String, dynamic> json) => DailyQuest(
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => QuestItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        completedCount: json['completed_count'] as int? ?? 0,
        isComplete: json['is_complete'] as bool? ?? false,
      );

  static const DailyQuest empty =
      DailyQuest(items: [], completedCount: 0, isComplete: false);
}

class StreakInfo {
  final int days;
  final int freezesAvailable;
  final List<DateTime> frozenDates;

  const StreakInfo({
    required this.days,
    required this.freezesAvailable,
    required this.frozenDates,
  });

  /// A run of one or two is not a run yet, and showing "1 day" to a child
  /// who has just started sets a counter at almost zero — the least
  /// motivating number there is. The streak appears once it is worth
  /// protecting.
  static const int showFrom = 3;

  bool get isWorthShowing => days >= showFrom;

  /// True when a freeze is holding the current run together, so the app
  /// can say so instead of pretending the child practised that day.
  bool get wasSaved => frozenDates.isNotEmpty;

  factory StreakInfo.fromJson(Map<String, dynamic> json) => StreakInfo(
        days: json['days'] as int? ?? 0,
        freezesAvailable: json['freezes_available'] as int? ?? 0,
        frozenDates: (json['frozen_dates'] as List<dynamic>? ?? [])
            .map((e) => DateTime.parse(e as String))
            .toList(),
      );

  static const StreakInfo none =
      StreakInfo(days: 0, freezesAvailable: 0, frozenDates: []);
}

class Collectible {
  final int phonemeId;
  final String symbol;
  final int order;
  final String phonemeType;
  final bool isUnlocked;
  final bool isNew;

  const Collectible({
    required this.phonemeId,
    required this.symbol,
    required this.order,
    required this.phonemeType,
    required this.isUnlocked,
    required this.isNew,
  });

  factory Collectible.fromJson(Map<String, dynamic> json) => Collectible(
        phonemeId: json['phoneme_id'] as int,
        symbol: json['symbol'] as String,
        order: json['order'] as int? ?? 0,
        phonemeType: json['phoneme_type'] as String? ?? 'alphabet',
        isUnlocked: json['is_unlocked'] as bool? ?? false,
        isNew: json['is_new'] as bool? ?? false,
      );
}

class Collection {
  final int total;
  final int unlocked;
  final List<Collectible> items;
  final List<int> newlyUnlocked;

  const Collection({
    required this.total,
    required this.unlocked,
    required this.items,
    required this.newlyUnlocked,
  });

  factory Collection.fromJson(Map<String, dynamic> json) => Collection(
        total: json['total'] as int? ?? 0,
        unlocked: json['unlocked'] as int? ?? 0,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => Collectible.fromJson(e as Map<String, dynamic>))
            .toList(),
        newlyUnlocked: (json['newly_unlocked'] as List<dynamic>? ?? [])
            .cast<int>(),
      );

  static const Collection empty =
      Collection(total: 0, unlocked: 0, items: [], newlyUnlocked: []);
}

class Story {
  final int exerciseId;
  final String title;
  final int wordCount;
  final bool isUnlocked;
  final String? blockingPhoneme;

  /// Null for locked stories — the server withholds it rather than
  /// trusting the client not to show it.
  final String? content;

  const Story({
    required this.exerciseId,
    required this.title,
    required this.wordCount,
    required this.isUnlocked,
    required this.blockingPhoneme,
    required this.content,
  });

  factory Story.fromJson(Map<String, dynamic> json) => Story(
        exerciseId: json['exercise_id'] as int,
        title: json['title'] as String? ?? 'A story',
        wordCount: json['word_count'] as int? ?? 0,
        isUnlocked: json['is_unlocked'] as bool? ?? false,
        blockingPhoneme: json['blocking_phoneme'] as String?,
        content: json['content'] as String?,
      );
}

class StoryShelf {
  final int total;
  final int unlocked;
  final List<Story> stories;

  const StoryShelf({
    required this.total,
    required this.unlocked,
    required this.stories,
  });

  factory StoryShelf.fromJson(Map<String, dynamic> json) => StoryShelf(
        total: json['total'] as int? ?? 0,
        unlocked: json['unlocked'] as int? ?? 0,
        stories: (json['stories'] as List<dynamic>? ?? [])
            .map((e) => Story.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static const StoryShelf empty = StoryShelf(total: 0, unlocked: 0, stories: []);
}
