class LessonEntity {
  final int id;
  final int order;
  final String level;
  final List<PhonemeEntity> phonemes;
  final int totalExercises;
  final int completedExercises;

  const LessonEntity({
    required this.id,
    required this.order,
    required this.level,
    required this.phonemes,
    required this.totalExercises,
    required this.completedExercises,
  });

  double get progressPercent =>
      totalExercises == 0 ? 0 : completedExercises / totalExercises;

  bool get isCompleted =>
      completedExercises >= totalExercises && totalExercises > 0;
  bool get isStarted => completedExercises > 0;
}

class PhonemeEntity {
  final int id;

  /// How the curriculum records this sound. **Never show this to a child.**
  ///
  /// It holds a mix of letter names ("Aa"), IPA ("ɪ", "dʒ", "kʰ", "ʌ/ə")
  /// and IPA-plus-spelling ("ʃ (sh)"). Rendering it is what put "D3" and
  /// "Kw" on the home screen in front of children learning J and Q — and
  /// for Y, stored as "Jj", a confident and entirely wrong letter. Kept
  /// because audio and the parent dashboard are keyed on it.
  final String symbol;

  /// The spellings this sound is written with, comma separated: "a",
  /// "sh", "ee,ea". This is the thing a child reads. See [letterForms].
  final String? graphemes;

  final String description;
  final String? audioUrl;
  final String type;
  final int order;

  const PhonemeEntity({
    required this.id,
    required this.symbol,
    this.graphemes,
    required this.description,
    this.audioUrl,
    required this.type,
    required this.order,
  });

  /// The spellings themselves: `["a"]`, `["sh"]`, `["ee", "ea"]`.
  ///
  /// Empty when the curriculum has not recorded one, and it deliberately
  /// does **not** fall back to [symbol]. A blank space is obviously wrong
  /// to anyone who looks at it; a wrong letter is not, and this app
  /// teaches children which letters make which sounds. Nothing is safer
  /// than something plausible and false.
  List<String> get spellings => (graphemes ?? '')
      .split(',')
      .map((g) => g.trim())
      .where((g) => g.isNotEmpty)
      .toList();

  /// Every spelling written capital then small, for the screen that
  /// teaches the sound: `a` becomes `["A a"]`, `sh` becomes `["SH sh"]`,
  /// and a sound spelled two ways shows both — `ee,ea` gives
  /// `["EE ee", "EA ea"]`.
  ///
  /// Capital first because that is the order these are named and written
  /// in — "Aa", not "aA".
  List<String> get letterForms =>
      spellings.map((g) => '${g.toUpperCase()} $g').toList();

  /// [letterForms] on one line, for the places that show a sound inline.
  ///
  /// This replaces a `dualCaseSymbol` that did string surgery on [symbol]:
  /// splitting on brackets and slashes, capitalising the first character
  /// and appending the lower-cased whole. For "Aa" that produced "Aa aa" —
  /// the letter twice, once right and once wrong — and for the IPA symbols
  /// it produced whatever the characters happened to look like.
  String get letters => letterForms.join('   ');
}
