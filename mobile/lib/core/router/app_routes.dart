abstract class AppRoutes {
  // ── Auth flow ─────────────────────────────────────────────────
  static const String splash      = '/';
  static const String onboarding  = '/onboarding';
  static const String login       = '/login';
  static const String register    = '/register';

  // ── Phone number auth (NEW) ───────────────────────────────────
  static const String phoneRegister = '/phone-register';
  static const String phoneLogin    = '/phone-login';
  // Deep link: phonicsfriends://join?token=...
  static const String joinInvite    = '/join';

  // ── Main shell (bottom nav) ───────────────────────────────────
  static const String home = '/home';

  // ── Phonics ───────────────────────────────────────────────────
  static const String lessons              = '/lessons';
  static const String lessonDetail         = '/lessons/:lessonId';
  static const String phonemeLesson        = '/lessons/:lessonId/phoneme/:phonemeId';
  static const String exercise             = '/lessons/:lessonId/exercise/:exerciseId';
  static const String pronunciationResult  = '/pronunciation-result';

  // ── Engagement ────────────────────────────────────────────────
  static const String collection = '/collection';
  static const String stories    = '/stories';

  /// The listening game. No microphone, no upload, no Azure — the one
  /// exercise a child can always do, whatever the connection.
  static const String recognition = '/find-the-sound';

  /// This week's promise and the prize for keeping it. Named for the week
  /// rather than for the goal: what the child is looking at is their own
  /// week, not a target somebody set them.
  static const String goal = '/my-week';

  /// Practise one exercise by id, with no lesson around it.
  ///
  /// [exercise] is nested under a lesson and needs a lessonId to build its
  /// path. The quest card and the story reader both hold an exercise id
  /// and nothing else — a quest item is deliberately drawn from wherever
  /// in the curriculum it fits best, so there is no one lesson it belongs
  /// to. This is that entry point.
  static const String practice = '/practice';

  // ── Spelling Bee ──────────────────────────────────────────────
  static const String spellingBee     = '/spelling-bee';
  static const String spellingBeeGame = '/spelling-bee/game';

  // ── Progress ──────────────────────────────────────────────────
  static const String progress = '/progress';

  // ── Profile ───────────────────────────────────────────────────
  static const String profile = '/profile';

  // ── Parent dashboard (NEW) ────────────────────────────────────
  static const String parentDashboard   = '/parent/dashboard';
  static const String parentRegister    = '/parent/register';
  static const String parentSettings    = '/parent/settings';
  static const String addChild          = '/parent/add-child';
  static const String parentChildDetail = '/parent/child';
  static const String inviteLinks       = '/parent/invite-links';
}