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

  /// Earned on the recognition track — the child can pick this symbol out
  /// of four when they hear the sound. It wakes the creature up without
  /// colouring it in, because knowing a sound when you see it and being
  /// able to say it are two different things and the shelf should show
  /// both.
  final bool isRecognised;

  const Collectible({
    required this.phonemeId,
    required this.symbol,
    required this.order,
    required this.phonemeType,
    required this.isUnlocked,
    required this.isNew,
    this.isRecognised = false,
  });

  factory Collectible.fromJson(Map<String, dynamic> json) => Collectible(
        phonemeId: json['phoneme_id'] as int,
        symbol: json['symbol'] as String,
        order: json['order'] as int? ?? 0,
        phonemeType: json['phoneme_type'] as String? ?? 'alphabet',
        isUnlocked: json['is_unlocked'] as bool? ?? false,
        isNew: json['is_new'] as bool? ?? false,
        isRecognised: json['is_recognised'] as bool? ?? false,
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

/// Two ways of asking the same question, forming a ladder.
///
/// In [explore] every symbol plays its own sound when tapped, so the child
/// can listen around before committing — a search they can verify rather
/// than a trap. In [choose] the target plays once and the symbols are
/// silent, which is recall. Only [choose] counts towards knowing a sound,
/// and the server enforces that; the app never has to decide.
enum RecognitionMode {
  explore,
  choose;

  String get wire => name;
}

class RecognitionOption {
  final int phonemeId;
  final String symbol;

  /// The spelling, which is what the child is actually looking at. The
  /// symbol may be IPA and IPA is not what a six-year-old reads.
  final String grapheme;
  final String audioUrl;

  const RecognitionOption({
    required this.phonemeId,
    required this.symbol,
    required this.grapheme,
    required this.audioUrl,
  });

  factory RecognitionOption.fromJson(Map<String, dynamic> json) =>
      RecognitionOption(
        phonemeId: json['phoneme_id'] as int,
        symbol: json['symbol'] as String? ?? '',
        grapheme: json['grapheme'] as String? ?? '',
        audioUrl: json['audio_url'] as String? ?? '',
      );
}

class RecognitionQuestion {
  /// The answer, sent with the question on purpose. A child cannot be left
  /// waiting on a round trip to find out whether they were right, so the
  /// app marks it on the device and posts the whole round afterwards.
  /// There is nothing here worth hiding: the app is not a competition and
  /// the phone belongs to the child.
  final int targetPhonemeId;
  final String targetAudioUrl;
  final List<RecognitionOption> options;

  const RecognitionQuestion({
    required this.targetPhonemeId,
    required this.targetAudioUrl,
    required this.options,
  });

  RecognitionOption get target =>
      options.firstWhere((o) => o.phonemeId == targetPhonemeId);

  bool isCorrect(int chosenPhonemeId) => chosenPhonemeId == targetPhonemeId;

  factory RecognitionQuestion.fromJson(Map<String, dynamic> json) =>
      RecognitionQuestion(
        targetPhonemeId: json['target_phoneme_id'] as int,
        targetAudioUrl: json['target_audio_url'] as String? ?? '',
        options: (json['options'] as List<dynamic>? ?? [])
            .map((e) => RecognitionOption.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class RecognitionRound {
  final RecognitionMode mode;
  final List<RecognitionQuestion> questions;

  const RecognitionRound({required this.mode, required this.questions});

  bool get isEmpty => questions.isEmpty;

  factory RecognitionRound.fromJson(Map<String, dynamic> json) =>
      RecognitionRound(
        mode: json['mode'] == 'choose'
            ? RecognitionMode.choose
            : RecognitionMode.explore,
        questions: (json['questions'] as List<dynamic>? ?? [])
            .map((e) => RecognitionQuestion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static const RecognitionRound empty =
      RecognitionRound(mode: RecognitionMode.explore, questions: []);
}

class RecognitionAnswer {
  final int phonemeId;

  /// Null when the child left the question without answering. Sent anyway
  /// and never counted wrong — a child who put the phone down has not
  /// confused anything.
  final int? chosenPhonemeId;
  final int optionCount;

  const RecognitionAnswer({
    required this.phonemeId,
    required this.chosenPhonemeId,
    required this.optionCount,
  });

  Map<String, dynamic> toJson() => {
        'phoneme_id': phonemeId,
        'chosen_phoneme_id': chosenPhonemeId,
        'option_count': optionCount,
      };
}

class RecognitionSummary {
  final int recorded;

  /// Sounds that crossed into "known by sight" because of this round, so
  /// the app can show those creatures waking at the moment it happened
  /// rather than silently next time the shelf is opened.
  final List<int> newlyRecognised;
  final int totalRecognised;

  const RecognitionSummary({
    required this.recorded,
    required this.newlyRecognised,
    required this.totalRecognised,
  });

  factory RecognitionSummary.fromJson(Map<String, dynamic> json) =>
      RecognitionSummary(
        recorded: json['recorded'] as int? ?? 0,
        newlyRecognised:
            (json['newly_recognised'] as List<dynamic>? ?? []).cast<int>(),
        totalRecognised: json['total_recognised'] as int? ?? 0,
      );

  static const RecognitionSummary none =
      RecognitionSummary(recorded: 0, newlyRecognised: [], totalRecognised: 0);
}

/// The three things a child may promise themselves for a week.
///
/// Kinds, not sizes. "I'll come every day" against "I'll wake up two
/// friends" is a choice about what to do; three sizes of one thing is a
/// difficulty slider, and a difficulty slider only ever gets pulled to
/// the bottom.
enum GoalKind {
  days,
  soundsFound,
  soundsMastered;

  static GoalKind fromWire(String raw) => switch (raw) {
        'sounds_found' => GoalKind.soundsFound,
        'sounds_mastered' => GoalKind.soundsMastered,
        _ => GoalKind.days,
      };

  String get wire => switch (this) {
        GoalKind.days => 'days',
        GoalKind.soundsFound => 'sounds_found',
        GoalKind.soundsMastered => 'sounds_mastered',
      };

  /// What the child is promising, in their own terms. Phrased as
  /// something they will do, never as something they should be.
  String label(int target) => switch (this) {
        GoalKind.days => 'Come and practise on $target days',
        GoalKind.soundsFound => 'Find $target sounds by listening',
        GoalKind.soundsMastered =>
          target == 1 ? 'Wake up a new friend' : 'Wake up $target new friends',
      };

  /// The short form, for the progress line once it is chosen.
  String get noun => switch (this) {
        GoalKind.days => 'days',
        GoalKind.soundsFound => 'sounds',
        GoalKind.soundsMastered => 'friends',
      };
}

class GoalOption {
  final GoalKind kind;
  final int target;

  const GoalOption({required this.kind, required this.target});

  factory GoalOption.fromJson(Map<String, dynamic> json) => GoalOption(
        kind: GoalKind.fromWire(json['kind'] as String? ?? 'days'),
        target: json['target'] as int? ?? 1,
      );
}

class EarnedWeek {
  final DateTime weekStart;

  /// What that week was spent on. The prize wears it, so a shelf reads as
  /// a run of decisions the child made rather than a row of identical
  /// tokens saying how many times they complied.
  final GoalKind kind;

  const EarnedWeek({required this.weekStart, required this.kind});

  factory EarnedWeek.fromJson(Map<String, dynamic> json) => EarnedWeek(
        weekStart: DateTime.parse(json['week_start'] as String),
        kind: GoalKind.fromWire(json['kind'] as String? ?? 'days'),
      );
}

/// What a grown-up promised for this week, as the child may see it.
///
/// [voiceUrl] arrives null until the goal is met — the server seals it, and
/// the client is not trusted to. What the child does get from Monday is
/// [hasVoice] and a name, which is the whole point: a message you know is
/// waiting is something to work towards, where one sprung on you
/// afterwards is just a payment.
class Promise {
  final String? text;

  /// Whose promise it is. "Your mum recorded this" is a different thing to
  /// a child than a message from an app.
  final String? parentName;
  final bool hasVoice;
  final String? voiceUrl;

  const Promise({
    required this.text,
    required this.parentName,
    required this.hasVoice,
    required this.voiceUrl,
  });

  /// True while there is a message the child has not earned yet.
  bool get isSealed => hasVoice && voiceUrl == null;

  factory Promise.fromJson(Map<String, dynamic> json) => Promise(
        text: json['text'] as String?,
        parentName: json['parent_name'] as String?,
        hasVoice: json['has_voice'] as bool? ?? false,
        voiceUrl: json['voice_url'] as String?,
      );
}

class WeeklyGoal {
  final DateTime weekStart;

  /// Null when the child has not chosen yet, which is a perfectly good
  /// state to be in and never nagged about.
  final GoalKind? kind;
  final int target;
  final int done;
  final bool isComplete;
  final List<GoalOption> choices;

  /// Every week this child finished. There is no matching list of weeks
  /// they did not — a shelf with gaps in it would be a record of failure,
  /// and this feature does not keep one.
  final List<EarnedWeek> earnedWeeks;

  /// Null when nobody has promised anything, which is the ordinary case
  /// and draws nothing at all. A child whose parent has not written
  /// something must never be shown the space where it would have been.
  final Promise? promise;

  const WeeklyGoal({
    required this.weekStart,
    required this.kind,
    required this.target,
    required this.done,
    required this.isComplete,
    required this.choices,
    required this.earnedWeeks,
    this.promise,
  });

  bool get isChosen => kind != null;

  /// How far round the ring the child has got. Capped, so overshooting
  /// never draws past full.
  double get fraction =>
      target <= 0 ? 0 : (done / target).clamp(0.0, 1.0).toDouble();

  int get remaining => target - done < 0 ? 0 : target - done;

  factory WeeklyGoal.fromJson(Map<String, dynamic> json) => WeeklyGoal(
        weekStart: DateTime.parse(json['week_start'] as String),
        kind: json['kind'] == null
            ? null
            : GoalKind.fromWire(json['kind'] as String),
        target: json['target'] as int? ?? 0,
        done: json['done'] as int? ?? 0,
        isComplete: json['is_complete'] as bool? ?? false,
        choices: (json['choices'] as List<dynamic>? ?? [])
            .map((e) => GoalOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        earnedWeeks: (json['earned_weeks'] as List<dynamic>? ?? [])
            .map((e) => EarnedWeek.fromJson(e as Map<String, dynamic>))
            .toList(),
        promise: json['promise'] == null
            ? null
            : Promise.fromJson(json['promise'] as Map<String, dynamic>),
      );

  static final WeeklyGoal none = WeeklyGoal(
    weekStart: DateTime.fromMillisecondsSinceEpoch(0),
    kind: null,
    target: 0,
    done: 0,
    isComplete: false,
    choices: const [],
    earnedWeeks: const [],
  );
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
