/// The steps a child works through for one sound.
///
/// Public, and in its own file, because these names are no longer private
/// to the lesson screen: they are written into the resume cursor, stored
/// on the device and on the server, and read back at launch — possibly by
/// a different build of the app than the one that wrote them.
///
/// That makes [named] the important part. A stage this build does not
/// recognise has to land somewhere a child can carry on from, because the
/// alternative happens at launch, before anything is on screen, to a child
/// who cannot navigate their way out of it.
enum LessonStage {
  /// Meet the sound: how it is written, and hear it.
  phonemeIntro,

  /// Say it.
  gate,

  /// Pick it out from the ones already learnt.
  quiz,

  /// Practise it in words.
  exercises;

  /// Resolves a stored name, falling back to the start of the sound.
  ///
  /// Null, empty, a stage that has been renamed, one from a newer build:
  /// all of them mean the same thing here, which is that we do not know
  /// where the child was and should begin the sound again. Repeating a
  /// step costs a child thirty seconds; a crash costs them the app.
  static LessonStage named(String? name) {
    for (final stage in LessonStage.values) {
      if (stage.name == name) return stage;
    }
    return LessonStage.phonemeIntro;
  }
}
