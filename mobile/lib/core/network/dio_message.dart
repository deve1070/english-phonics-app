import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// What to tell someone when a request fails.
///
/// Every failure used to arrive as "No internet connection. Please try
/// again." — one sentence covering four unrelated dio failures. When a
/// debug build could not reach a local backend because Android was
/// blocking cleartext, that sentence was the only explanation on offer and
/// it was false: the wifi was fine and the server was answering. It cost
/// an afternoon looking at the wrong thing.
///
/// So these say what is actually known and no more. "Couldn't reach the
/// server" is true whether the phone is offline, the host is wrong, the
/// backend is down or the platform refused the connection; "no internet"
/// is true only in the first case and is the least likely of the four
/// during development.
///
/// In debug builds the underlying cause is appended. A child never sees
/// it — release builds get the plain sentence — but whoever is holding the
/// phone when it breaks is usually the person who can fix it.
String describeDioError(DioException e, {String? whileDoing}) {
  final plain = switch (e.type) {
    DioExceptionType.connectionTimeout =>
      "Couldn't reach the server. It may be waking up — try again in a moment.",
    DioExceptionType.sendTimeout => 'Sending took too long. Please try again.',
    DioExceptionType.receiveTimeout =>
      'The server is taking too long to answer. Please try again.',
    DioExceptionType.badCertificate =>
      "Couldn't verify the server. Please try again.",
    DioExceptionType.cancel => 'That was cancelled.',
    DioExceptionType.connectionError =>
      "Couldn't reach the server. Please try again.",
    DioExceptionType.badResponse => _fromResponse(e, whileDoing),
    DioExceptionType.unknown =>
      "Something went wrong reaching the server. Please try again.",
  };

  if (!kDebugMode || e.type == DioExceptionType.badResponse) return plain;

  // The bit that would have saved the afternoon: which dio failure it was,
  // where it was going, and what the platform actually said.
  final cause = e.error?.toString() ?? e.message ?? '';
  final target = e.requestOptions.uri.toString();
  return '$plain\n\n[debug] ${e.type.name} → $target'
      '${cause.isEmpty ? '' : '\n$cause'}';
}

String _fromResponse(DioException e, String? whileDoing) {
  // The server's own words first: it knows why it refused.
  final data = e.response?.data;
  if (data is Map) {
    final detail = data['detail'] ?? data['message'];
    if (detail != null && detail.toString().trim().isNotEmpty) {
      return detail.toString();
    }
  }
  final code = e.response?.statusCode ?? 0;
  return switch (code) {
    401 => 'Please log in again.',
    403 => "You don't have access to that.",
    404 => whileDoing == null
        ? "That isn't there any more."
        : "Couldn't find $whileDoing.",
    >= 500 => 'The server had a problem. Please try again.',
    _ => whileDoing == null
        ? 'Something went wrong. Please try again.'
        : "Couldn't load $whileDoing. Please try again.",
  };
}
