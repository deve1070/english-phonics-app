import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../phonics/data/datasources/exercises_remote_datasource.dart';
import '../../../phonics/data/datasources/lessons_remote_datasource.dart';
import 'phonics_state.dart';

class PhonicsCubit extends Cubit<PhonicsState> {
  final LessonsRemoteDataSource _lessonsDataSource;
  final ExercisesRemoteDataSource _exercisesDataSource;
  final AudioPlayer _audioPlayer;
  final AudioRecorder _recorder;
  final Dio _dio;

  String? _recordingPath;
  Timer? _gateAutoStopTimer;
  bool _gateStopInProgress = false;

  PhonicsCubit(
    this._lessonsDataSource,
    this._exercisesDataSource,
    this._audioPlayer,
    this._recorder,
    this._dio,
  ) : super(const PhonicsInitial());

  factory PhonicsCubit.create() {
    final dio = getIt<Dio>();
    return PhonicsCubit(
      LessonsRemoteDataSource(dio),
      ExercisesRemoteDataSource(dio),
      AudioPlayer(),
      AudioRecorder(),
      dio,
    );
  }

  // ── Load lesson ───────────────────────────────────────────────
  Future<void> loadLesson(int lessonId) async {
    emit(const PhonicsLoading());
    try {
      final lesson = await _lessonsDataSource.getLessonById(lessonId);
      final exercises =
          await _exercisesDataSource.getExercisesForLesson(lessonId);
      emit(PhonicsLoaded(lesson: lesson, exercises: exercises));
    } on DioException catch (e) {
      emit(PhonicsError(e.message ?? 'Failed to load lesson'));
    } catch (e) {
      emit(PhonicsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  // ── Navigate phonemes ─────────────────────────────────────────

  /// Jumps straight to a phoneme by id, for resuming.
  ///
  /// Silently does nothing if the id is not in this lesson: a cursor can
  /// outlive a curriculum change, and a child returning after one should
  /// start the lesson from the top rather than meet an error.
  void goToPhoneme(int phonemeId) {
    final state = this.state;
    if (state is! PhonicsLoaded) return;
    final index = state.lesson.phonemes.indexWhere((p) => p.id == phonemeId);
    if (index < 0 || index == state.currentPhonemeIndex) return;
    emit(state.copyWith(
      currentPhonemeIndex: index,
      isPlayingAudio: false,
      phonemeUnlocked: false,
      lastGateScore: null,
      isGateRecording: false,
      isGateScoring: false,
    ));
  }

  void nextPhoneme() {
    final state = this.state;
    if (state is PhonicsLoaded && !state.isLastPhoneme) {
      emit(state.copyWith(
        currentPhonemeIndex: state.currentPhonemeIndex + 1,
        isPlayingAudio: false,
        phonemeUnlocked: false,
        lastGateScore: null,
        isGateRecording: false,
        isGateScoring: false,
      ));
    }
  }

  void previousPhoneme() {
    final state = this.state;
    if (state is PhonicsLoaded && !state.isFirstPhoneme) {
      emit(state.copyWith(
        currentPhonemeIndex: state.currentPhonemeIndex - 1,
        isPlayingAudio: false,
        phonemeUnlocked: false,
        lastGateScore: null,
        isGateRecording: false,
        isGateScoring: false,
      ));
    }
  }

  // ── Play phoneme audio ────────────────────────────────────────
  Future<void> playPhonemeAudio(int phonemeId) async {
    final state = this.state;
    if (state is! PhonicsLoaded) return;

    emit(state.copyWith(isPlayingAudio: true));
    try {
      final response = await _dio.get<List<int>>(
        ApiConstants.phonemeAudio(phonemeId),
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      if (response.data == null || response.data!.isEmpty) {
        throw Exception('Empty audio response');
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/phoneme_$phonemeId.mp3');
      await tempFile.writeAsBytes(response.data!);

      await _audioPlayer.stop();
      await _audioPlayer.setFilePath(tempFile.path);
      await _audioPlayer.play();

      await _audioPlayer.playerStateStream.firstWhere(
        (s) =>
            s.processingState == ProcessingState.completed ||
            s.processingState == ProcessingState.idle,
      );
    } on DioException catch (e) {
      _handleAudioError(e, state);
      return;
    } catch (_) {
      // Non-fatal
    } finally {
      if (!isClosed && this.state is PhonicsLoaded) {
        emit((this.state as PhonicsLoaded).copyWith(isPlayingAudio: false));
      }
    }
  }

  // ── Pronunciation gate ────────────────────────────────────────
  Future<void> startGateRecording() async {
    final state = this.state;
    if (state is! PhonicsLoaded) return;
    if (state.isGateRecording || state.isGateScoring || _gateStopInProgress) {
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    _gateAutoStopTimer?.cancel();
    _gateAutoStopTimer = null;

    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/gate_${DateTime.now().millisecondsSinceEpoch}.wav';

    // Record as WAV (PCM) so backend/assessment receives uncompressed PCM.
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav),
      path: _recordingPath!,
    );

    emit(state.copyWith(isGateRecording: true));

    // Auto-stop so the kid isn't stuck recording forever.
    _gateAutoStopTimer = Timer(const Duration(seconds: 6), () {
      if (!isClosed) {
        unawaited(stopAndSubmitGate());
      }
    });
  }

  Future<void> stopAndSubmitGate() async {
    final state0 = state;
    if (state0 is! PhonicsLoaded) return;
    if (!state0.isGateRecording) return;
    if (_gateStopInProgress) return;
    _gateStopInProgress = true;

    _gateAutoStopTimer?.cancel();
    _gateAutoStopTimer = null;

    try {
      // Update UI immediately — `_recorder.stop()` can hang on some devices
      // until the encoder finishes; the user should see "stopped" right away.
      emit(state0.copyWith(isGateRecording: false, isGateScoring: true));

      try {
        await _recorder.stop().timeout(const Duration(seconds: 5));
      } on TimeoutException {
        // Best-effort: continue so scoring / error handling still runs.
      } catch (_) {
        // Same — do not block the flow on a stuck native recorder.
      }

      if (isClosed) return;
      final state = this.state;
      if (state is! PhonicsLoaded) return;

      if (_recordingPath == null || state.currentPhoneme == null) {
        emit(state.copyWith(isGateScoring: false, lastGateScore: 0.0));
        return;
      }

      try {
        final formData = FormData.fromMap({
          'audio': await MultipartFile.fromFile(
            _recordingPath!,
            filename: 'gate.wav',
          ),
        });

        final phonemeId = state.currentPhoneme!.id;
        final response = await _dio.post(
          ApiConstants.submitPhonemePronunciation(phonemeId),
          data: formData,
        );

        final score = (response.data['score'] as num).toDouble();
        final passed = score >= PhonicsLoaded.gatePassScore;

        if (!isClosed && this.state is PhonicsLoaded) {
          emit((this.state as PhonicsLoaded).copyWith(
            isGateScoring: false,
            phonemeUnlocked: passed,
            lastGateScore: score,
          ));
        }
      } catch (_) {
        if (!isClosed && this.state is PhonicsLoaded) {
          emit((this.state as PhonicsLoaded)
              .copyWith(isGateScoring: false, phonemeUnlocked: false));
        }
        emit(const PhonicsError(
            'Could not score your voice. Please try again and speak louder.'));
      }
    } finally {
      _gateStopInProgress = false;
    }
  }

  // ── AI exercise generation ────────────────────────────────────
  Future<void> generateExercises(int lessonId, int phonemeId) async {
    final state = this.state;
    if (state is! PhonicsLoaded) return;

    emit(state.copyWith(isGeneratingExercises: true));
    try {
      await _dio.post(
        ApiConstants.generateExercises,
        queryParameters: {'phoneme_id': phonemeId},
      );
      // Wait for background task to generate at least some exercises
      await Future.delayed(const Duration(seconds: 4));
      final exercises =
          await _exercisesDataSource.getExercisesForLesson(lessonId);
      if (!isClosed && this.state is PhonicsLoaded) {
        emit((this.state as PhonicsLoaded).copyWith(
          exercises: exercises,
          isGeneratingExercises: false,
        ));
      }
    } on DioException catch (e) {
      final detail = _extractDetail(e);
      if (!isClosed && this.state is PhonicsLoaded) {
        emit((this.state as PhonicsLoaded)
            .copyWith(isGeneratingExercises: false));
      }
      emit(PhonicsError(detail));
      await Future.delayed(const Duration(seconds: 3));
      if (!isClosed) emit(state.copyWith(isGeneratingExercises: false));
    } catch (_) {
      if (!isClosed && this.state is PhonicsLoaded) {
        emit((this.state as PhonicsLoaded)
            .copyWith(isGeneratingExercises: false));
      }
    }
  }

  // ── Finish lesson ─────────────────────────────────────────────
  /// Marks lesson exercises as completed, returns the next lesson id if any.
  Future<int?> finishLesson() async {
    final state = this.state;
    if (state is! PhonicsLoaded) return null;

    // Update backend progress so next lesson unlocks.
    try {
      await _dio.post(ApiConstants.completeLesson(state.lesson.id));
    } catch (_) {
      // Non-fatal — still attempt navigation.
    }

    try {
      final lessons = await _lessonsDataSource.getLessons();
      final idx = lessons.indexWhere((l) => l.id == state.lesson.id);
      if (idx < 0) return null;
      if (idx >= lessons.length - 1) return null;
      return lessons[idx + 1].id;
    } catch (_) {
      // Fallback: assume sequential ids/orders
      return state.lesson.id + 1;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────
  void _handleAudioError(DioException e, PhonicsLoaded state) {
    String msg = 'Audio error';
    final rawData = e.response?.data;
    if (rawData is List<int>) {
      final match = RegExp(r'"detail"\s*:\s*"([^"]+)"')
          .firstMatch(String.fromCharCodes(rawData));
      msg = match?.group(1) ?? e.message ?? msg;
    } else if (rawData is Map) {
      msg = rawData['detail']?.toString() ?? e.message ?? msg;
    }
    emit(PhonicsError('Could not play audio: $msg'));
    Future.delayed(const Duration(seconds: 2), () {
      if (!isClosed) emit(state.copyWith(isPlayingAudio: false));
    });
  }

  String _extractDetail(DioException e) {
    final rawData = e.response?.data;
    if (rawData is Map) {
      return rawData['detail']?.toString() ?? e.message ?? 'Error';
    }
    if (rawData is List<int>) {
      final match = RegExp(r'"detail"\s*:\s*"([^"]+)"')
          .firstMatch(String.fromCharCodes(rawData));
      return match?.group(1) ?? e.message ?? 'Error';
    }
    return e.message ?? 'Error';
  }

  @override
  Future<void> close() {
    _gateAutoStopTimer?.cancel();
    _gateAutoStopTimer = null;
    _audioPlayer.dispose();
    _recorder.dispose();
    return super.close();
  }
}
