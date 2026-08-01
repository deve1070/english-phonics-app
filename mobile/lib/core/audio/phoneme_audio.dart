import 'dart:io';

import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';

/// Plays a phoneme's sound, fetching it at most once per device.
///
/// The recognition game is built entirely out of these: a round of five
/// questions with four options each can ask for twenty sounds, and every
/// one of them may be tapped several times while the child listens
/// around. Re-downloading on each tap would make the game unplayable on
/// the connections these children have, and would put a delay between a
/// child's finger and a sound — which in this exercise is not a
/// performance problem but a teaching one. The sound has to arrive while
/// they are still looking at the symbol.
///
/// So each sound is written to the cache directory and read from disk
/// afterwards, including on later runs of the app. Phoneme audio is
/// generated once on the server and never changes, so there is nothing to
/// invalidate; the OS clears the directory when it needs the space.
class PhonemeAudio {
  final Dio _dio;
  final AudioPlayer _player = AudioPlayer();

  /// Downloads already in flight, so tapping the same symbol twice
  /// before the first fetch lands does not start a second one.
  final Map<int, Future<String?>> _inFlight = {};
  final Map<int, String> _ready = {};

  Directory? _dir;

  PhonemeAudio(this._dio);

  /// Fetch these sounds into the cache without playing them.
  ///
  /// Called as a round opens, so by the time the child has read the
  /// question every option is already on the device. Failures are
  /// deliberately swallowed — a sound that could not be prefetched is
  /// simply fetched again when tapped.
  Future<void> prefetch(Iterable<int> phonemeIds) async {
    await Future.wait(phonemeIds.toSet().map(_path));
  }

  /// Play a sound from the start, interrupting whatever was playing.
  ///
  /// Interrupting is right for this game: a child who taps three symbols
  /// quickly wants the third sound, not all three at once.
  Future<void> play(int phonemeId) async {
    final path = await _path(phonemeId);
    if (path == null) return;
    try {
      await _player.stop();
      await _player.setFilePath(path);
      await _player.play();
    } catch (_) {
      // A corrupt or unplayable file must not take the game down with
      // it. Drop it from the cache so the next tap re-fetches.
      _ready.remove(phonemeId);
    }
  }

  Future<String?> _path(int phonemeId) {
    final ready = _ready[phonemeId];
    if (ready != null) return Future.value(ready);
    return _inFlight.putIfAbsent(phonemeId, () => _fetch(phonemeId));
  }

  Future<String?> _fetch(int phonemeId) async {
    try {
      final dir = _dir ??= await getTemporaryDirectory();
      final file = File('${dir.path}/phoneme_$phonemeId.mp3');

      if (await file.exists() && await file.length() > 0) {
        _ready[phonemeId] = file.path;
        return file.path;
      }

      final response = await _dio.get<List<int>>(
        ApiConstants.phonemeAudio(phonemeId),
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;

      await file.writeAsBytes(bytes);
      _ready[phonemeId] = file.path;
      return file.path;
    } catch (_) {
      return null;
    } finally {
      _inFlight.remove(phonemeId);
    }
  }

  Future<void> dispose() => _player.dispose();
}
