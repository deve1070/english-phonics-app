import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/constants/app_constants.dart';
import 'spelling_bee_state.dart';

class SpellingBeeCubit extends Cubit<SpellingBeeState> {
  final AudioPlayer _player;
  final Dio _dio;
  final Random _random = Random();

  static const List<String> _easyWords = [
    'cat',
    'bat',
    'hat',
    'rat',
    'mat',
    'sat',
    'bed',
    'red',
    'fed',
    'led',
    'wed',
    'big',
    'dig',
    'pig',
    'wig',
    'fig',
    'hop',
    'mop',
    'top',
    'pop',
    'bug',
    'hug',
    'mug',
    'rug',
    'jug',
    'cap',
    'map',
    'nap',
    'tap',
    'gap',
    'hen',
    'ten',
    'den',
    'pen',
    'hit',
    'bit',
    'fit',
    'sit',
    'kit',
  ];

  static const List<String> _mediumWords = [
    'cake',
    'lake',
    'make',
    'take',
    'wake',
    'bake',
    'kite',
    'bite',
    'mite',
    'site',
    'lite',
    'bone',
    'cone',
    'lone',
    'tone',
    'zone',
    'ship',
    'chip',
    'drip',
    'trip',
    'grip',
    'frog',
    'blog',
    'clog',
    'slog',
    'play',
    'clay',
    'stay',
    'tray',
    'pray',
    'blue',
    'clue',
    'glue',
    'true',
    'fish',
    'dish',
    'wish',
    'rush',
    'bush',
    'ring',
    'king',
    'sing',
    'wing',
    'ping',
  ];

  static const List<String> _hardWords = [
    'spring',
    'string',
    'splash',
    'strong',
    'plane',
    'crane',
    'flame',
    'grade',
    'brave',
    'shave',
    'stave',
    'crave',
    'bloom',
    'broom',
    'gloom',
    'stool',
    'brain',
    'train',
    'drain',
    'plain',
    'beach',
    'teach',
    'reach',
    'peach',
    'cloud',
    'proud',
    'shout',
    'scout',
    'night',
    'light',
    'fight',
    'sight',
    'right',
    'catch',
    'match',
    'patch',
    'watch',
    'batch',
  ];

  static const int _totalRounds = 5;
  final List<String> _usedWords = [];

  SpellingBeeDifficulty _currentDifficulty = SpellingBeeDifficulty.easy;
  int _consecutiveCorrect = 0;
  static const int _advanceThreshold = 2;

  SpellingBeeCubit(this._player, this._dio) : super(const SpellingBeeInitial());

  factory SpellingBeeCubit.create() => SpellingBeeCubit(
        AudioPlayer(),
        getIt<Dio>(),
      );

  void startGame() {
    _usedWords.clear();
    _currentDifficulty = SpellingBeeDifficulty.easy;
    _consecutiveCorrect = 0;
    _loadNextRound(round: 1, score: 0);
  }

  void _loadNextRound({required int round, required int score}) {
    final wordBank = _wordBankForDifficulty(_currentDifficulty);
    final available = wordBank.where((w) => !_usedWords.contains(w)).toList();

    if (available.isEmpty) {
      emit(SpellingBeeDone(finalScore: score, totalRounds: _totalRounds));
      return;
    }

    final word = available[_random.nextInt(available.length)];
    _usedWords.add(word);

    final letters = word.split('');
    final decoys = _getDecoys(word, 2);
    final allLetters = [...letters, ...decoys]..shuffle(_random);

    emit(SpellingBeeReady(
      word: word,
      shuffledLetters: allLetters,
      placedLetters: List.filled(word.length, null),
      hasPlayedAudio: false,
      score: score,
      round: round,
      totalRounds: _totalRounds,
      difficulty: _currentDifficulty,
    ));

    Future.delayed(
      const Duration(milliseconds: 600),
      () => playWordAudio(),
    );
  }

  // FIX: robust TTS with 3-tier fallback
  // Tier 1: backend POST /tts/synthesize (bytes response)
  // Tier 2: backend GET with audio stream (if tier 1 gives 404)
  // Tier 3: just_audio URL from a free TTS service
  Future<void> playWordAudio() async {
    final state = this.state;
    if (state is! SpellingBeeReady) return;

    bool played = false;

    // ── Tier 1: Backend /tts/synthesize ───────────────────────
    try {
      final response = await _dio.post(
        ApiConstants.ttsSynthesize,
        data: {'text': state.word},
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.data != null) {
        final bytes = response.data as List<int>;
        if (bytes.isNotEmpty) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/spelling_${state.word}.mp3');
          await tempFile.writeAsBytes(bytes);
          await _player.stop();
          await _player.setFilePath(tempFile.path);
          await _player.play();
          played = true;
        }
      }
    } catch (e) {
      print('Spelling Bee Tier 1 TTS failed: $e');
    }

    // ── Tier 2: Free TTS URL fallback ─────────────────────────
    if (!played) {
      try {
        // Google TTS public endpoint (no API key, may have rate limits)
        final url = 'https://translate.google.com/translate_tts'
            '?ie=UTF-8&q=${Uri.encodeComponent(state.word)}'
            '&tl=en&client=tw-ob';
        await _player.stop();
        await _player.setUrl(url, headers: {
          'User-Agent': 'Mozilla/5.0 (compatible)',
        });
        await _player.play();
        played = true;
      } catch (_) {
        // Tier 2 also failed
      }
    }

    // Mark as played regardless — don't block the game
    if (!isClosed && this.state is SpellingBeeReady) {
      emit((this.state as SpellingBeeReady).copyWith(hasPlayedAudio: true));
    }
  }

  void placeLetter(String letter) {
    final state = this.state;
    if (state is! SpellingBeeReady) return;
    final placed = List<String?>.from(state.placedLetters);
    final emptyIndex = placed.indexOf(null);
    if (emptyIndex == -1) return;
    placed[emptyIndex] = letter;
    emit(state.copyWith(placedLetters: placed));
  }

  void removeLast() {
    final state = this.state;
    if (state is! SpellingBeeReady) return;
    final placed = List<String?>.from(state.placedLetters);
    for (int i = placed.length - 1; i >= 0; i--) {
      if (placed[i] != null) {
        placed[i] = null;
        emit(state.copyWith(placedLetters: placed));
        return;
      }
    }
  }

  void removeLetterAt(int slotIndex) {
    final state = this.state;
    if (state is! SpellingBeeReady) return;
    final placed = List<String?>.from(state.placedLetters);
    if (slotIndex < placed.length) {
      placed[slotIndex] = null;
      emit(state.copyWith(placedLetters: placed));
    }
  }

  void checkAnswer() {
    final state = this.state;
    if (state is! SpellingBeeReady || !state.isComplete) return;

    final isCorrect = state.isCorrect;
    final newScore = isCorrect ? state.score + 1 : state.score;

    if (isCorrect) {
      _consecutiveCorrect++;
      if (_consecutiveCorrect >= _advanceThreshold) {
        _consecutiveCorrect = 0;
        _currentDifficulty = _nextDifficulty(_currentDifficulty);
      }
    } else {
      _consecutiveCorrect = 0;
    }

    emit(SpellingBeeResult(
      word: state.word,
      isCorrect: isCorrect,
      score: newScore,
      round: state.round,
      totalRounds: state.totalRounds,
      difficulty: _currentDifficulty,
      wasCorrect: isCorrect,
    ));
  }

  void nextRound() {
    final state = this.state;
    if (state is! SpellingBeeResult) return;
    if (state.isFinalRound) {
      emit(SpellingBeeDone(
          finalScore: state.score, totalRounds: state.totalRounds));
    } else {
      _loadNextRound(round: state.round + 1, score: state.score);
    }
  }

  void restartGame() => startGame();

  List<String> _wordBankForDifficulty(SpellingBeeDifficulty d) {
    switch (d) {
      case SpellingBeeDifficulty.easy:
        return _easyWords;
      case SpellingBeeDifficulty.medium:
        return _mediumWords;
      case SpellingBeeDifficulty.hard:
        return _hardWords;
    }
  }

  SpellingBeeDifficulty _nextDifficulty(SpellingBeeDifficulty d) {
    switch (d) {
      case SpellingBeeDifficulty.easy:
        return SpellingBeeDifficulty.medium;
      case SpellingBeeDifficulty.medium:
        return SpellingBeeDifficulty.hard;
      case SpellingBeeDifficulty.hard:
        return SpellingBeeDifficulty.hard;
    }
  }

  List<String> _getDecoys(String word, int count) {
    const alphabet = 'abcdefghijklmnoprstw';
    final wordLetters = word.split('');
    final decoys = <String>[];
    while (decoys.length < count) {
      final letter = alphabet[_random.nextInt(alphabet.length)].toString();
      if (!wordLetters.contains(letter) && !decoys.contains(letter)) {
        decoys.add(letter);
      }
    }
    return decoys;
  }

  @override
  Future<void> close() {
    _player.dispose();
    return super.close();
  }
}
