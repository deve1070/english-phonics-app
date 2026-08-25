import 'package:flutter/foundation.dart';

abstract class ApiConstants {
  // ── Backend URL ───────────────────────────────────────────────
  //
  // Chosen by build mode rather than edited by hand. It was a single
  // constant that had to be swapped to develop and swapped back to ship,
  // which is a line of code that is wrong half the time and only ever
  // noticed by whoever gets the broken build.
  //
  // Debug runs against the machine you are developing on; release always
  // goes to production, so a build cannot be shipped pointing at somebody's
  // wifi. Either can be overridden without touching this file:
  //
  //   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
  //
  // Note the two local addresses are not interchangeable. The Android
  // emulator reaches the host at 10.0.2.2; a real phone needs the host's
  // address on the wifi you are both on (`ip addr | grep 192.168`), and
  // must be on that same wifi.
  static const String productionUrl =
      'https://english-phonics-app.onrender.com/api/v1';
  static const String _localUrl = 'http://192.168.0.126:8000/api/v1';

  static const String _override = String.fromEnvironment('API_BASE_URL');

  static final String baseUrl = _override.isNotEmpty
      ? _override
      : (kReleaseMode ? productionUrl : _localUrl);

  /// Generous because the production host sleeps when idle and takes the
  /// best part of a minute to wake up.
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ── Auth ──────────────────────────────────────────────────────
  // Passwordless: phone number only. Two tokens, no refresh token —
  // a 7-day access_token (JWT) plus a biometric_token redeemed via
  // passkeyLogin, which rotates it on every use.
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String passkeyLogin = '/auth/passkey-login';
  static const String me = '/users/me';

  // ── Invite links ──────────────────────────────────────────────
  // WARNING: the backend has an InviteLink model but exposes NO
  // endpoints for it. Every route below 404s today — JoinScreen and
  // InviteLinksScreen are dead UI until the backend side is built.
  static const String joinWithInvite = '/auth/join';
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

  // No /progress, /gamification, /friends or /subscriptions here: the
  // backend exposes none of them. A constant would only hand a caller a
  // route to 404 on.

  // ── TTS ───────────────────────────────────────────────────────
  static const String ttsSynthesize = '/tts/synthesize';

  // ── Engagement (the child's own view) ─────────────────────────
  // No child id in any of these: the server scopes them to whoever the
  // token belongs to. A parent token gets 403, by design.
  static const String questToday = '/me/quest/today';
  static const String myStreak = '/me/streak';
  static const String myCollection = '/me/collection';
  static const String collectionSeen = '/me/collection/seen';
  static const String myStories = '/me/stories';

  /// Where the child stopped. GET to resume, PUT on every step.
  static const String myCursor = '/me/cursor';

  /// "Which symbol says this sound?" — GET builds a round, POST records
  /// the finished one. The same path for both: a round is a resource the
  /// child is handed and hands back.
  static const String recognitionRound = '/me/recognition/round';

  /// This week's promise. GET returns the goal or the three choices,
  /// POST makes the choice. The target is always the server's to decide.
  static const String myGoal = '/me/goal';

  // ── Parent management ─────────────────────────────────────────
  static const String parentRegister = '/parents/register';
  static const String parentDashboard = '/parents/dashboard';
  static const String parentChildren = '/parents/children';
  static String parentChildProgress(int id) => '/parents/children/$id/progress';
  static String parentWeeklyReport(int id) =>
      '/parents/children/$id/weekly-report';
  static String parentChildGoals(int id) => '/parents/children/$id/goals';
  static String parentChildLogin(int id) => '/parents/child-login/$id';

  /// This week's promise, from the parent's side — nothing withheld.
  static String parentPromise(int id) => '/parents/children/$id/promise';
  static String parentPromiseVoice(int id) =>
      '/parents/children/$id/promise/voice';
  static String parentChildScreenTime(int id) =>
      '/parents/children/$id/screen-time';
  static String parentChildStartSession(int id) =>
      '/parents/children/$id/start-session';
  static String parentChildEndSession(int id) =>
      '/parents/children/$id/end-session';
}

abstract class StorageKeys {
  static const String accessToken = 'access_token';
  /// Legacy. Nothing writes this any more — kept only so clearTokens()
  /// still wipes it from installs that predate the two-token model.
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String userRole = 'user_role';
  static const String subscriptionStatus = 'subscription_status';
  /// Redeemed at `/auth/passkey-login`; the server rotates it on use.
  static const String biometricToken = 'biometric_token';
  /// User opted in to “unlock with Face ID / fingerprint / device PIN” after OTP sign-in.
  static const String biometricUnlockEnabled = 'biometric_unlock_enabled';
  /// The child's session, kept while the parent is in the dashboard.
  static const String childToken = 'child_token';
  /// Parent JWT retained while the active [accessToken] is the child's session.
  static const String parentAccessToken = 'parent_access_token';

  /// Which child's learning session is currently open. Needed to close the
  /// screen-time session later, since end-session is addressed by child id
  /// and the child's own token may already be gone by then.
  static const String activeChildId = 'active_child_id';
  static const String onboardingDone = 'onboarding_done';
}

abstract class AssetPaths {
  // The mascot paths that were here are gone. There were three characters
  // behind them — a monster, an elephant filed as the monster's "excited"
  // face, and a bird — and a child cannot have a companion who keeps
  // turning into a different animal. Kiki is a widget now: see
  // core/mascot/kiki.dart, which owns her artwork and picks the pose.
  static const String loadingAnimation = 'assets/animations/loading.json';
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
