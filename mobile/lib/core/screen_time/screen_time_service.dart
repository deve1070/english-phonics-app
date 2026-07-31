import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../network/token_storage.dart';

/// Opens and closes the child's screen-time session on the backend.
///
/// Time only counts toward `max_daily_minutes` once a session has been
/// closed — the server sums completed sessions — so an unclosed session is
/// worse than no session at all: it contributes nothing and leaves a
/// dangling row that blocks the next `start-session` from opening a new one
/// (start is idempotent and returns the existing open session).
///
/// Both endpoints accept either the parent's token or the child's own,
/// which matters because sessions get closed in states where only one of
/// the two is still available.
class ScreenTimeService {
  final Dio _dio;
  final TokenStorage _tokenStorage;

  ScreenTimeService(this._dio, this._tokenStorage);

  /// Opens a session and records which child it belongs to.
  ///
  /// The child id is persisted rather than held in memory because the
  /// session usually has to be closed from a different screen, or on a
  /// later app launch after the process was killed.
  Future<void> startSession(int childId) async {
    await _tokenStorage.saveActiveChildId(childId);
    try {
      await _dio.post(ApiConstants.parentChildStartSession(childId));
    } on DioException catch (e) {
      // Never block entry to the learning view on screen-time bookkeeping.
      developer.log(
        'start-session failed for child $childId: ${e.message}',
        name: 'ScreenTime',
      );
    }
  }

  /// Closes whatever session is currently open, if any. Safe to call when
  /// none is open — the server no-ops and this clears local state anyway.
  ///
  /// [forget] false keeps the stored child id so the session can be reopened,
  /// which is what backgrounding needs: the time so far is banked, but the
  /// child hasn't left their session.
  Future<void> endSession({bool forget = true}) async {
    final childId = await _tokenStorage.getActiveChildId();
    if (childId == null) return;

    try {
      await _dio.post(ApiConstants.parentChildEndSession(childId));
    } on DioException catch (e) {
      developer.log(
        'end-session failed for child $childId: ${e.message}',
        name: 'ScreenTime',
      );
    } finally {
      // Clear regardless of the outcome. A retained id after a failed close
      // would make the next endSession() target a stale child; the server
      // reuses the dangling session on the next start anyway.
      if (forget) await _tokenStorage.clearActiveChildId();
    }
  }

  /// Reopens the session for the child who was mid-session when the app was
  /// backgrounded, so only foreground time is counted.
  ///
  /// No-op when a parent is the active user — they may have switched to the
  /// dashboard while the id was still stored, and their browsing should not
  /// count against the child's daily limit.
  Future<void> resumeSession() async {
    final childId = await _tokenStorage.getActiveChildId();
    if (childId == null) return;
    if (await _tokenStorage.isParent) return;

    try {
      await _dio.post(ApiConstants.parentChildStartSession(childId));
    } on DioException catch (e) {
      developer.log(
        'resume start-session failed for child $childId: ${e.message}',
        name: 'ScreenTime',
      );
    }
  }
}
