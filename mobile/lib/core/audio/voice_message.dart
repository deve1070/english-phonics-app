import 'dart:io';

import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// Plays a recorded voice message fetched from the API.
///
/// Separate from [PhonemeAudio] and deliberately so. A phoneme's sound is
/// permanent and shared by every child, so it is cached by id forever; a
/// parent's message is one file that can be re-recorded on Wednesday, and
/// caching it by anything but the request itself would hand a child last
/// week's take. This fetches once per instance and no further, which is
/// exactly the life of one screen.
///
/// Failures are swallowed and reported as "nothing to play" rather than
/// thrown. A recording that will not download is a disappointment; an
/// error dialog on top of it is a second one.
class VoiceMessage {
  final Dio _dio;
  final AudioPlayer _player = AudioPlayer();

  String? _path;
  Future<String?>? _inFlight;

  VoiceMessage(this._dio);

  bool get isPlaying => _player.playing;

  /// Whether the audio is on the device and ready to play instantly.
  bool get isReady => _path != null;

  Stream<PlayerState> get state => _player.playerStateStream;

  /// Fetch without playing, so the moment the child earns it there is no
  /// wait between the celebration and their parent's voice.
  Future<bool> prefetch(String url) async => (await _fetch(url)) != null;

  Future<void> play(String url) async {
    final path = await _fetch(url);
    if (path == null) return;
    try {
      await _player.stop();
      await _player.setFilePath(path);
      await _player.play();
    } catch (_) {
      _path = null;
    }
  }

  Future<String?> _fetch(String url) {
    final ready = _path;
    if (ready != null) return Future.value(ready);
    return _inFlight ??= _download(url);
  }

  Future<String?> _download(String url) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/promise_voice.mp3');

      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;

      await file.writeAsBytes(bytes);
      _path = file.path;
      return file.path;
    } catch (_) {
      return null;
    } finally {
      _inFlight = null;
    }
  }

  Future<void> dispose() => _player.dispose();
}
