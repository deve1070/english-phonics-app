abstract class ApiConstants {
  static const String baseUrl = 'https://english-phonics-app.onrender.com/api/v1';
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // ── Auth (existing) ───────────────────────────────────────────
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken =
      '/auth/refresh'; // keep — AuthInterceptor uses this
  static const String me = '/users/me';

  // ── Auth (phone number — NEW) ─────────────────────────────────
  static const String sendOTP = '/auth/send-otp';
  static const String verifyOTP = '/auth/verify-otp';
  static const String registerPhone = '/auth/register-phone';
  static const String biometricLogin = '/auth/biometric-login';
  static const String joinWithInvite = '/auth/join';

  // ── Invite links (NEW) ────────────────────────────────────────
  static const String generateInviteLink = '/auth/invite-link';
  static const String listInviteLinks = '/auth/me/invite-links';
  static String revokeInviteLink(int id) => '/auth/invite-links/$id';

  // ── Lessons ───────────────────────────────────────────────────
  static const String lessons = '/lessons/';
  static String lessonById(int id) => '/lessons/$id';
  static String lessonExercises(int id) =>
      '/lessons/$id/exercises'; // keep — used by exercises datasource
  static String completeLesson(int id) => '/lessons/$id/complete';

  // ── Phonemes ──────────────────────────────────────────────────
  static const String phonemes = '/phonemes/';
  static String phonemeById(int id) => '/phonemes/$id';
  static String phonemeAudio(int id) => '/phonemes/$id/audio';

  // ── Exercises ─────────────────────────────────────────────────
  static String exerciseById(int id) => '/exercises/$id';
  static String submitPronunciation(int id) =>
      '/exercises/$id/submit-pronunciation';
  static String submitPhonemePronunciation(int id) =>
      '/phonemes/$id/submit-pronunciation';
  static String referenceAudio(int id) => '/exercises/$id/reference-audio';
  static const String generateExercises = '/exercises/generate';

  // ── Progress ──────────────────────────────────────────────────
  static const String recommended = '/progress/me/recommended';
  static const String feedback = '/progress/me/feedback';

  // ── Gamification ──────────────────────────────────────────────
  static const String badges = '/gamification/badges';
  static const String myAchievements =
      '/gamification/me/achievements'; // keep — used by gamification datasource
  static const String achievements = '/gamification/me/achievements';
  static const String awardPoints = '/gamification/me/award-points';

  // ── Friends ───────────────────────────────────────────────────
  static const String friendRequest = '/friends/request';
  static const String pendingRequests = '/friends/requests/pending';
  static const String myFriends = '/friends/friends';
  static const String friendRecommend = '/friends/recommend';

  // ── TTS ───────────────────────────────────────────────────────
  static const String ttsSynthesize = '/tts/synthesize';
  static const String ttsPhonemeWithVisemes = '/tts/phoneme-with-visemes';

  // ── Parent management ─────────────────────────────────────────
  static const String parentDashboard = '/parents/dashboard';
  static const String parentChildren = '/parents/children';
  static String parentChildProgress(int id) => '/parents/children/$id/progress';
  static String parentWeeklyReport(int id) =>
      '/parents/children/$id/weekly-report';
  static String parentChildGoals(int id) => '/parents/children/$id/goals';
  static String parentChildLogin(int id) => '/parents/child-login/$id';
  static String parentChildScreenTime(int id) =>
      '/parents/children/$id/screen-time';

  // ── Subscription ──────────────────────────────────────────────
  static const String subscriptions = '/subscriptions/';
  static const String mySubscription = '/subscriptions/me';
}

abstract class StorageKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String userRole = 'user_role';
  static const String subscriptionStatus = 'subscription_status';
  // NEW — biometric passkey-like token
  static const String biometricToken = 'biometric_token';
  /// User opted in to “unlock with Face ID / fingerprint / device PIN” after OTP sign-in.
  static const String biometricUnlockEnabled = 'biometric_unlock_enabled';
  // NEW — preserved child token when parent switches to dashboard
  static const String childToken = 'child_token';
  /// Parent JWT retained while the active [accessToken] is the child's session.
  static const String parentAccessToken = 'parent_access_token';
  static const String onboardingDone = 'onboarding_done';
}

abstract class AssetPaths {
  static const String mascot = 'assets/images/popi.png';
  static const String mascotExcited = 'assets/images/popiE.png';
  static const String mascotIntro = 'assets/images/im.png';
  static const String hero1 = 'assets/images/image.png';
  static const String hero2 = 'assets/images/image2.png';
  static const String loadingAnimation = 'assets/animations/loading.json';
  static const String phonicsMouthRive = 'assets/animations/phonics_mouth.riv';
  static String mouthAnimation(String t) => 'assets/animations/mouth/$t.json';
  static String phonemeAudioAsset(String s) => 'assets/audio/phonemes/$s.mp3';
}

abstract class LevelConstants {
  static const Map<String, String> labels = {
    'LEVEL1': 'Starter',
    'LEVEL2': 'Explorer',
    'LEVEL3': 'Reader',
    'LEVEL4': 'Speaker',
    'LEVEL5': 'Champion',
  };
}

abstract class ScoreThresholds {
  static const double pass = 80.0;
  static const double good = 90.0;
  static const double perfect = 98.0;
}

abstract class SubscriptionStatus {
  static const String trial = 'TRIAL';
  static const String active = 'ACTIVE';
  static const String canceled = 'CANCELED';
  static const String pastDue = 'PAST_DUE';
  static bool isAllowed(String? status) => status == trial || status == active;
}

abstract class DeepLinkConstants {
  static const String scheme = 'phonicsfriends';
  static const String joinPath = '/join';
  static const String tokenParam = 'token';
  static String buildInviteLink(String token) => '$scheme://join?token=$token';
  static String? parseToken(Uri uri) => uri.queryParameters[tokenParam];
}
