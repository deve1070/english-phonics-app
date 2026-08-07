import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/audio/phoneme_audio.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/mascot/kiki.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/session/day_plan.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/pressable.dart';
import '../../data/engagement_models.dart';
import '../../data/engagement_remote_datasource.dart';

/// "Which one says this?" — the listening game.
///
/// This is the only exercise in the app that needs no microphone, no
/// upload and no call to Azure, which on these connections makes it the
/// one a child can always do. It is also the rung below speaking:
/// recognising a symbol by its sound comes first developmentally, and a
/// child who cannot yet make /th/ can absolutely point at it.
///
/// Two ways to play, and the child climbs from one to the other inside a
/// single sitting. In [RecognitionMode.explore] a tap plays that symbol's
/// sound and a second tap on the same symbol chooses it — so nobody
/// answers a sound they have not heard, and listening around is part of
/// the game rather than cheating at it. In [RecognitionMode.choose] the
/// symbols are silent and one tap answers. Only the second counts towards
/// knowing a sound; the server decides that, not this screen.
///
/// Marking happens on the device. A six-year-old cannot be left watching
/// a spinner to find out whether they were right, so the answer travels
/// with the question and the whole round is posted at the end.
class RecognitionScreen extends StatefulWidget {
  final RecognitionMode initialMode;

  const RecognitionScreen({
    super.key,
    this.initialMode = RecognitionMode.explore,
  });

  @override
  State<RecognitionScreen> createState() => _RecognitionScreenState();
}

enum _Phase { asking, right, wrong }

/// The round is finished, so the day moves on by itself.
///
/// The child taps "Done" and the next activity simply arrives. Sending
/// them back to a screen to choose from would put the decision they are
/// least able to make right where they are most pleased with themselves.
Future<void> _handOnToNext(BuildContext context) async {
  final next = await getIt<DayRunner>().advance(DayActivity.findTheSound);
  if (!context.mounted) return;
  context.go(next);
}

class _RecognitionScreenState extends State<RecognitionScreen> {
  late final EngagementRemoteDataSource _source =
      EngagementRemoteDataSource(getIt<Dio>());
  late final PhonemeAudio _audio = PhonemeAudio(getIt<Dio>());

  late RecognitionMode _mode = widget.initialMode;
  RecognitionRound? _round;
  String? _error;

  int _index = 0;
  _Phase _phase = _Phase.asking;

  /// The option the child has heard but not yet committed to, in explore
  /// mode. Null in choose mode, where a tap is an answer.
  int? _armed;
  int? _chosen;

  final List<RecognitionAnswer> _answers = [];
  int _found = 0;
  bool _posted = false;
  RecognitionSummary? _summary;

  /// The week's goal, once a round has just finished it. Only ever set on
  /// the round that crosses the target.
  WeeklyGoal? _keptTheWeek;
  Timer? _advance;

  bool get _isDone => _round != null && _index >= _round!.questions.length;
  RecognitionQuestion? get _question =>
      (_round == null || _isDone) ? null : _round!.questions[_index];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _advance?.cancel();
    // A child who walks away mid-round still gets what they did recorded,
    // with the unanswered questions sent as unanswered rather than wrong.
    // Fire and forget: the screen is going, the Dio instance is not, and
    // the datasource swallows its own failures.
    unawaited(_post());
    unawaited(_audio.dispose());
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _round = null;
      _error = null;
      _index = 0;
      _phase = _Phase.asking;
      _armed = null;
      _chosen = null;
      _answers.clear();
      _found = 0;
      _posted = false;
      _summary = null;
    });
    try {
      final round = await _source.getRecognitionRound(mode: _mode);
      if (!mounted) return;
      setState(() => _round = round);

      // Pull every sound the round can ask for onto the device before the
      // child touches anything. Twenty small files fetched once beats one
      // fetched per tap on a connection that may not manage either.
      unawaited(_audio.prefetch([
        for (final q in round.questions) ...q.options.map((o) => o.phonemeId),
      ]).then((_) => _playTarget()));
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message ?? 'Could not start the game');
    }
  }

  Future<void> _playTarget() async {
    final question = _question;
    if (question == null) return;
    await _audio.play(question.targetPhonemeId);
  }

  void _tap(RecognitionOption option) {
    final question = _question;
    if (question == null || _phase != _Phase.asking) return;

    if (_mode == RecognitionMode.explore && _armed != option.phonemeId) {
      // First tap: hear it. Every card plays its own true sound — the app
      // never puts a sound behind the wrong symbol, because a child who
      // hears /b/ while looking at "d" has just been taught that link.
      setState(() => _armed = option.phonemeId);
      _audio.play(option.phonemeId);
      return;
    }

    _answer(question, option);
  }

  void _answer(RecognitionQuestion question, RecognitionOption option) {
    final correct = question.isCorrect(option.phonemeId);
    setState(() {
      _chosen = option.phonemeId;
      _phase = correct ? _Phase.right : _Phase.wrong;
      if (correct) _found += 1;
    });

    _answers.add(RecognitionAnswer(
      phonemeId: question.targetPhonemeId,
      chosenPhonemeId: option.phonemeId,
      optionCount: question.options.length,
    ));

    // Either way the child hears the right sound beside the right symbol.
    // On a wrong answer that is the whole repair: the correct card lights
    // up and says itself, so the last thing they experience is the true
    // pairing rather than their mistake.
    _audio.play(question.targetPhonemeId);

    _advance = Timer(
      correct ? const Duration(milliseconds: 900) : const Duration(seconds: 2),
      _next,
    );
  }

  void _next() {
    if (!mounted) return;
    setState(() {
      _index += 1;
      _phase = _Phase.asking;
      _armed = null;
      _chosen = null;
    });
    if (_isDone) {
      _finish();
    } else {
      _playTarget();
    }
  }

  Future<void> _finish() async {
    final summary = await _post();
    if (!mounted) return;
    setState(() => _summary = summary);

    // The week is most often kept here rather than on the goal screen —
    // a child finishes a round and the count crosses their target. If
    // nobody says so, the message their parent recorded sits behind a
    // screen they have no reason to open, and the moment it was made for
    // passes in silence.
    final goal = await _source.getGoal();
    if (!mounted) return;
    if (goal.isComplete) setState(() => _keptTheWeek = goal);
  }

  /// Send the round, padding out anything the child never reached.
  ///
  /// Called both at the end and from [dispose], so it has to be safe to
  /// call twice — a round posted a second time would double every answer
  /// in it and hand the child a streak they did not earn.
  Future<RecognitionSummary> _post() async {
    final round = _round;
    if (round == null || _posted || _answers.isEmpty) {
      return RecognitionSummary.none;
    }
    _posted = true;

    final answered = _answers.map((a) => a.phonemeId).toSet();
    final full = [
      ..._answers,
      for (final q in round.questions)
        if (!answered.contains(q.targetPhonemeId))
          RecognitionAnswer(
            phonemeId: q.targetPhonemeId,
            chosenPhonemeId: null,
            optionCount: q.options.length,
          ),
    ];

    return _source.submitRecognitionRound(mode: round.mode, answers: full);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        backgroundColor: AppColors.parchment,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 18, color: AppColors.ink),
          // Backing out without finishing, which does not count as done —
          // the round will be offered again. `pop` alone is not enough:
          // when the day handed this screen over there is nothing beneath
          // it on the stack to pop back to.
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
        title: Text('Find the sound', style: AppTextStyles.headingSmall),
        centerTitle: true,
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    final error = _error;
    if (error != null) return _Message(text: error, onRetry: _load);

    final round = _round;
    if (round == null) {
      return const Center(child: Kiki(size: 120, mood: KikiMood.thinking));
    }
    if (round.isEmpty) {
      return _Message(
        text: 'No sounds to play with yet.\nTry a lesson first.',
        onRetry: _load,
      );
    }

    final summary = _summary;
    if (summary != null || _isDone) {
      return _RoundSummary(
        right: _found,
        total: round.questions.length,
        summary: summary ?? RecognitionSummary.none,
        mode: round.mode,
        keptTheWeek: _keptTheWeek,
        onSeeWeek: () => context.push(AppRoutes.goal),
        onAgain: (mode) {
          setState(() => _mode = mode);
          _load();
        },
        onDone: () => _handOnToNext(context),
      );
    }

    return _Question(
      question: _question!,
      mode: _mode,
      phase: _phase,
      armed: _armed,
      chosen: _chosen,
      index: _index,
      total: round.questions.length,
      onReplay: _playTarget,
      onTapOption: _tap,
    );
  }
}

// ── One question ─────────────────────────────────────────────────────

class _Question extends StatelessWidget {
  final RecognitionQuestion question;
  final RecognitionMode mode;
  final _Phase phase;
  final int? armed;
  final int? chosen;
  final int index;
  final int total;
  final VoidCallback onReplay;
  final void Function(RecognitionOption) onTapOption;

  const _Question({
    required this.question,
    required this.mode,
    required this.phase,
    required this.armed,
    required this.chosen,
    required this.index,
    required this.total,
    required this.onReplay,
    required this.onTapOption,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _Dots(done: index, total: total),
        ),
        const SizedBox(height: AppSpacing.lg),
        _SoundButton(
          onTap: onReplay,
          mood: switch (phase) {
            _Phase.asking => KikiMood.listening,
            _Phase.right => KikiMood.celebrating,
            _Phase.wrong => KikiMood.encouraging,
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          switch ((phase, mode)) {
            (_Phase.right, _) => 'Yes!',
            (_Phase.wrong, _) => 'This one says it.',
            (_, RecognitionMode.explore) => 'Tap to listen. Tap again to pick.',
            (_, RecognitionMode.choose) => 'Which one says it?',
          },
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.inkSoft),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Two across whatever the count, so a card is always the
                // same size and always big enough for a small finger.
                final width =
                    (constraints.maxWidth - AppSpacing.md) / 2;
                return Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    runAlignment: WrapAlignment.center,
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      for (final option in question.options)
                        SizedBox(
                          width: width,
                          height: width * 0.82,
                          child: _OptionCard(
                            option: option,
                            state: _stateOf(option),
                            showSpeaker: mode == RecognitionMode.explore &&
                                phase == _Phase.asking,
                            onTap: () => onTapOption(option),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  _OptionState _stateOf(RecognitionOption option) {
    if (phase == _Phase.asking) {
      return option.phonemeId == armed ? _OptionState.armed : _OptionState.idle;
    }
    if (option.phonemeId == question.targetPhonemeId) return _OptionState.right;
    if (option.phonemeId == chosen) return _OptionState.wrong;
    return _OptionState.dimmed;
  }
}

/// How many questions are left, without a number.
///
/// A counter reads as a test. Dots read as a short walk with an end in
/// sight, which is the whole reason a round is five questions long.
class _Dots extends StatelessWidget {
  final int done;
  final int total;
  const _Dots({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          Container(
            width: i == done ? 14 : 10,
            height: i == done ? 14 : 10,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done
                  ? AppColors.leaf
                  : i == done
                      ? AppColors.honey
                      : AppColors.borderSoft,
              border: Border.all(color: AppColors.ink, width: 1.5),
            ),
          ),
      ],
    );
  }
}

/// The sound itself, as a thing you can press again.
class _SoundButton extends StatelessWidget {
  final VoidCallback onTap;
  final KikiMood mood;
  const _SoundButton({required this.onTap, required this.mood});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      color: AppColors.honeyLight,
      radius: AppRadius.full,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      semanticLabel: 'Play the sound again',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kiki is the app's voice everywhere else, so the sound comes
          // from her here too rather than from an anonymous speaker. She
          // needs room around her — cramped against the pill's edge she
          // reads as clipped rather than sitting in it.
          Kiki(size: 56, mood: mood),
          const SizedBox(width: AppSpacing.md),
          const Icon(Icons.volume_up_rounded, size: 34, color: AppColors.ink),
        ],
      ),
    );
  }
}

enum _OptionState { idle, armed, right, wrong, dimmed }

class _OptionCard extends StatelessWidget {
  final RecognitionOption option;
  final _OptionState state;
  final bool showSpeaker;
  final VoidCallback onTap;

  const _OptionCard({
    required this.option,
    required this.state,
    required this.showSpeaker,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Pressable(
      onTap: state == _OptionState.dimmed ? null : onTap,
      color: switch (state) {
        _OptionState.idle => AppColors.surface,
        _OptionState.armed => AppColors.skyLight,
        _OptionState.right => AppColors.leafLight,
        // Honey, not red. AppColors.retry exists precisely for "not that
        // one, have another go", and a six-year-old who has just picked a
        // letter does not need to be shown an error. The green card
        // beside it is doing the teaching.
        _OptionState.wrong => AppColors.honeyLight,
        _OptionState.dimmed => AppColors.surfaceSunken,
      },
      borderColor: switch (state) {
        _OptionState.right => AppColors.leaf,
        _OptionState.wrong => AppColors.retry,
        _ => AppColors.border,
      },
      borderWidth: state == _OptionState.idle
          ? AppBorders.standard
          : AppBorders.heavy,
      padding: const EdgeInsets.all(AppSpacing.sm),
      semanticLabel: option.grapheme.isEmpty ? option.symbol : option.grapheme,
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Text(
                // The spelling, not the symbol: IPA is for the curriculum,
                // and a child picking a sound out of four is looking for
                // the letters they will meet in a book.
                option.grapheme.isEmpty ? option.symbol : option.grapheme,
                style: AppTextStyles.phonemeDisplay.copyWith(
                  color: state == _OptionState.dimmed
                      ? AppColors.inkFaint
                      : AppColors.ink,
                ),
              ),
            ),
          ),
          // Top right, clear of descenders. Anchored to the card rather
          // than to the letter, or it lands on the tail of a g.
          if (showSpeaker)
            Positioned(
              right: 0,
              top: 0,
              child: Icon(
                state == _OptionState.armed
                    ? Icons.volume_up_rounded
                    : Icons.volume_up_outlined,
                size: 22,
                color: state == _OptionState.armed
                    ? AppColors.sky
                    : AppColors.inkFaint,
              ),
            ),
        ],
      ),
    );

    return switch (state) {
      // The right answer arrives with a small lift; the wrong one shakes
      // once and stays put. Nothing here punishes — the wrong card is
      // never crossed out or taken away, it simply stops being the one
      // that is lit.
      _OptionState.right =>
        card.animate().scale(begin: const Offset(1, 1), end: const Offset(1.06, 1.06), duration: 200.ms, curve: Curves.easeOut),
      _OptionState.wrong =>
        card.animate().shakeX(amount: 4, duration: 320.ms),
      _ => card,
    };
  }
}

// ── The end of a round ───────────────────────────────────────────────

class _RoundSummary extends StatelessWidget {
  final int right;
  final int total;
  final RecognitionSummary summary;
  final RecognitionMode mode;

  /// Set when this round finished the week's goal. Null the rest of the
  /// time, which is nearly always.
  final WeeklyGoal? keptTheWeek;
  final void Function(RecognitionMode) onAgain;
  final VoidCallback onDone;
  final VoidCallback onSeeWeek;

  const _RoundSummary({
    required this.right,
    required this.total,
    required this.summary,
    required this.mode,
    required this.keptTheWeek,
    required this.onAgain,
    required this.onDone,
    required this.onSeeWeek,
  });

  /// Where the child goes next: always the harder rung, offered rather
  /// than imposed. After a listening round, the same game without the
  /// listening is the natural step up, and taking it is the child's
  /// decision — which is most of what makes it feel like theirs.
  static const RecognitionMode _nextRung = RecognitionMode.choose;

  @override
  Widget build(BuildContext context) {
    final woken = summary.newlyRecognised.length;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Kiki(
              size: 120,
              mood: right > 0 ? KikiMood.celebrating : KikiMood.encouraging,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              // Counted up, never down: "$right found" and not "$wrong
              // missed". The same round, and a completely different thing
              // to have been part of.
              right == total
                  ? 'You found them all!'
                  : right == 1
                      ? 'You found one!'
                      : 'You found $right!',
              style: AppTextStyles.headingMedium,
              textAlign: TextAlign.center,
            ),
            if (woken > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                woken == 1
                    ? 'A friend opened its eyes.'
                    : '$woken friends opened their eyes.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.inkSoft),
                textAlign: TextAlign.center,
              ),
            ],
            if (keptTheWeek != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _WeekKept(goal: keptTheWeek!, onTap: onSeeWeek),
            ],
            const SizedBox(height: AppSpacing.xl),
            Pressable(
              onTap: () => onAgain(_nextRung),
              color: AppColors.leaf,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.md),
              child: Text(
                mode == RecognitionMode.explore
                    ? 'Try without listening'
                    : 'Play again',
                style:
                    AppTextStyles.buttonMedium.copyWith(color: AppColors.onInk),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: onDone,
              child: Text(
                'Done for now',
                style: AppTextStyles.buttonMedium
                    .copyWith(color: AppColors.inkSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The week finished, said here rather than left to be discovered.
///
/// It leads to the goal screen rather than playing the message inline:
/// what the child should see first is the medal they have been watching
/// all week, now filled, with their parent's voice next to it. Playing it
/// here would hand over the payoff with the prize still on another
/// screen.
class _WeekKept extends StatelessWidget {
  final WeeklyGoal goal;
  final VoidCallback onTap;

  const _WeekKept({required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = goal.promise?.parentName;
    final hasMessage = goal.promise?.voiceUrl != null;

    return Pressable(
      onTap: onTap,
      color: AppColors.honeyLight,
      borderColor: AppColors.border,
      padding: const EdgeInsets.all(AppSpacing.md),
      semanticLabel: 'You finished your week',
      child: Column(
        children: [
          // An envelope before any words. This card carries the one thing
          // on the screen a child cannot afford to skim past, and at six
          // the picture is read before the sentence is.
          Icon(
            hasMessage ? Icons.mark_email_unread_rounded : Icons.military_tech_rounded,
            size: 34,
            color: AppColors.honey,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('You finished your week!', style: AppTextStyles.headingSmall),
          const SizedBox(height: 2),
          Text(
            hasMessage
                ? (name == null
                    ? 'There is a message waiting for you.'
                    : '$name left you a message. Tap to hear it.')
                : 'Come and see your prize.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.ink),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  const _Message({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Kiki(size: 96, mood: KikiMood.thinking),
            const SizedBox(height: AppSpacing.lg),
            Text(text,
                style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            Pressable(
              onTap: onRetry,
              color: AppColors.leaf,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.md),
              child: Text('Try again',
                  style: AppTextStyles.buttonMedium
                      .copyWith(color: AppColors.onInk)),
            ),
          ],
        ),
      ),
    );
  }
}
