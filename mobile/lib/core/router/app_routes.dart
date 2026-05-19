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