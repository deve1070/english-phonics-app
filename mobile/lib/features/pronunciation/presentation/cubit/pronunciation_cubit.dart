import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import 'pronunciation_state.dart';

class PronunciationCubit extends Cubit<PronunciationState> {
  final Dio _dio;
  final AudioRecorder _recorder;
  final AudioPlayer _player;

  Timer? _countdownTimer;
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;
  String? _recordingPath;

  /// Best score per exercise for this sitting, so a retry can be framed as
  /// beating a record rather than repeating a failure. The server is the
  /// permanent record; this only needs to survive the screen.
  final Map<int, double> _bestByExercise = {};

  PronunciationCubit(this._dio, this._recorder, this._player)
      : super(const PronunciationInitial());

  factory PronunciationCubit.create() {
    return PronunciationCubit(
      getIt<Dio>(),
      AudioRecorder(),
      AudioPlayer(),
    );
  }

  // ── Play reference audio ──────────────────────────────────────
  Future<void> playReference(int exerciseId) async {
    emit(const PronunciationPlayingReference());
    try {
      // FIX: use correct reference audio endpoint
      // was: submitPronunciation(exerciseId) + '/reference' (wrong)
      // now: referenceAudio(exerciseId) → /exercises/{id}/reference-audio
      final response = await _dio.get<List<int>>(
        ApiConstants.referenceAudio(exerciseId),
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      if (response.data == null || response.data!.isEmpty) {
        // Non-fatal — reference audio may not exist yet
        if (!isClosed) emit(const PronunciationInitial());
        return;
      }

      // Write to temp file and play
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/reference_$exerciseId.mp3');
      await tempFile.writeAsBytes(response.data!);

      await _player.stop();
      await _player.setFilePath(tempFile.path);
      await _player.play();

      await _player.playerStateStream.firstWhere(
        (s) =>
            s.processingState == ProcessingState.completed ||
            s.processingState == ProcessingState.idle,
      );
    } catch (_) {
      // Non-fatal — reference audio failure should not block the user
    } finally {
      if (!isClosed) emit(const PronunciationInitial());
    }
  }

  // ── Start countdown then record ───────────────────────────────
  Future<void> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      emit(const PronunciationError(
          'Microphone permission is required. Please enable it in settings.'));
      return;
    }

    // Countdown 3 → 2 → 1
    for (int i = 3; i >= 1; i--) {
      emit(PronunciationCountdown(i));
      await Future.delayed(const Duration(seconds: 1));
      if (isClosed) return;
    }

    // Start recording
    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/pronunciation_${DateTime.now().millisecondsSinceEpoch}.wav';

    // Record as WAV (PCM) so backend/assessment receives uncompressed PCM.
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav),
      path: _recordingPath!,
    );

    _elapsed = Duration.zero;
    emit(const PronunciationRecording());

    // Track elapsed time + auto-stop at 10 seconds
    _elapsedTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _elapsed += const Duration(milliseconds: 100);
      if (!isClosed) emit(PronunciationRecording(elapsed: _elapsed));
      if (_elapsed.inSeconds >= 10) stopRecording();
    });
  }

  // ── Stop recording ────────────────────────────────────────────
  Future<void> stopRecording() async {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    await _recorder.stop();
    if (isClosed) return;
    emit(const PronunciationScoring());
  }

  // ── Submit audio to backend ───────────────────────────────────
  Future<void> submitAudio(int exerciseId) async {
    if (_recordingPath == null) return;
    emit(const PronunciationScoring());

    try {
      final file = File(_recordingPath!);
      final fileLen = await file.length();
      // Debug: ensure file has data before upload
      print('Pronunciation recording size: $fileLen bytes; path=$_recordingPath');
      if (!await file.exists()) {
        emit(const PronunciationError('Recording file not found.'));
        return;
      }

      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          _recordingPath!,
          filename: 'pronunciation.wav',
        ),
      });

      print('Pronunciation submit POST -> ${ApiConstants.submitPronunciation(exerciseId)}');

      final response = await _dio.post(
        ApiConstants.submitPronunciation(exerciseId),
        data: formData,
      );

      final score = (response.data['score'] as num).toDouble();

      // `your_speech` is what Azure actually transcribed. It drives the
      // per-word feedback — the difference between telling a child "44" and
      // showing them which word tripped them up.
      final heard = (response.data['your_speech'] ?? '').toString();

      // Best is tracked per exercise so switching exercises doesn't carry a
      // stale record across.
      final previousBest = _bestByExercise[exerciseId];
      final isBest = previousBest == null || score > previousBest;
      if (isBest) _bestByExercise[exerciseId] = score;

      emit(PronunciationScored(
        score: score,
        exerciseId: exerciseId,
        isCompleted: score >= ScoreThresholds.pass,
        heardText: heard,
        bestScore: _bestByExercise[exerciseId],
        // Only celebrate a record when there was something to beat.
        isPersonalBest: isBest && previousBest != null,
      ));
    } on DioException catch (e) {
      print('Pronunciation submit failed: ${e.message}');
      emit(PronunciationError(
        e.response?.data?['detail'] ?? 'Could not score your pronunciation.',
      ));
    } catch (e) {
      emit(PronunciationError(e.toString()));
    }
  }

  // ── Stop then immediately submit ──────────────────────────────
  Future<void> stopAndSubmit(int exerciseId) async {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    await _recorder.stop();
    if (!isClosed) await submitAudio(exerciseId);
  }

  void reset() {
    _countdownTimer?.cancel();
    _elapsedTimer?.cancel();
    emit(const PronunciationInitial());
  }

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    _elapsedTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    return super.close();
  }
}
