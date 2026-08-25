import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/audio/voice_message.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/network/dio_message.dart';

/// Where a parent answers the goal their child set themselves.
///
/// Two things go on this screen and neither is a target. The parent does
/// not get to decide what the child aims for — that is the child's, and
/// handing it to a grown-up turns the whole feature back into homework.
/// What a parent can do is promise something real for the week, and leave
/// a few seconds of their own voice for the moment it is finished.
///
/// The prompt asks what the family will *do*, not what the child will
/// *get*. Paying a child for something they were enjoying anyway can
/// replace their reason for doing it with the payment; an afternoon
/// together cannot. It is a nudge in the wording and nothing more — what
/// a family promises each other is not the app's business to approve.
///
/// The recording matters more than the writing, and for a specific
/// reason: it needs no literacy in either language. A parent who cannot
/// read the English their child is learning can still say "I'm proud of
/// you" into a phone, and their child will hear it in the moment they
/// earned it rather than hours later.
class PromiseScreen extends StatefulWidget {
  final int childId;
  const PromiseScreen({super.key, required this.childId});

  @override
  State<PromiseScreen> createState() => _PromiseScreenState();
}

class _PromiseScreenState extends State<PromiseScreen> {
  final Dio _dio = getIt<Dio>();
  late final VoiceMessage _playback = VoiceMessage(_dio);

  /// Built on the first tap of the record button, not on open. Its
  /// constructor reaches for the platform straight away, and most parents
  /// on most weeks will write a line and never record anything.
  AudioRecorder? _recorder;
  final TextEditingController _text = TextEditingController();

  Map<String, dynamic>? _promise;
  String? _error;
  bool _saving = false;
  bool _recording = false;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _recorder?.dispose();
    _playback.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await _dio.get(ApiConstants.parentPromise(widget.childId));
      if (!mounted) return;
      final data = r.data as Map<String, dynamic>;
      setState(() {
        _promise = data;
        _text.text = (data['text'] as String?) ?? '';
      });
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _error = describeDioError(e, whileDoing: 'the promise'));
      }
    }
  }

  Future<void> _saveText() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final r = await _dio.put(
        ApiConstants.parentPromise(widget.childId),
        data: {'text': _text.text.trim().isEmpty ? null : _text.text.trim()},
      );
      if (!mounted) return;
      setState(() => _promise = r.data as Map<String, dynamic>);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved. Your child can see it now.')),
      );
    } on DioException catch (e) {
      if (mounted) setState(() => _error = describeDioError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_recording) return _stopRecording();

    final recorder = _recorder ??= AudioRecorder();
    if (!await recorder.hasPermission()) {
      if (mounted) {
        setState(() => _error = 'The app needs permission to use the mic.');
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/promise_take.m4a';
    await recorder.start(const RecordConfig(), path: path);
    if (!mounted) return;
    setState(() {
      _recording = true;
      _startedAt = DateTime.now();
      _error = null;
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder?.stop();
    final seconds = _startedAt == null
        ? 0.0
        : DateTime.now().difference(_startedAt!).inMilliseconds / 1000;
    if (!mounted) return;
    setState(() => _recording = false);

    if (path == null) return;
    if (seconds < 1) {
      // A half-second of silence is a slip of the finger, not a message.
      setState(() => _error = 'That was too short — hold on a bit longer.');
      return;
    }

    setState(() => _saving = true);
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(path, filename: 'promise.m4a'),
        'seconds': seconds.toStringAsFixed(1),
      });
      final r = await _dio.post(
        ApiConstants.parentPromiseVoice(widget.childId),
        data: form,
      );
      if (!mounted) return;
      setState(() => _promise = r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _error =
            e.response?.data?['detail']?.toString() ?? 'Could not send it');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _playBack() =>
      _playback.play(ApiConstants.parentPromiseVoice(widget.childId));

  @override
  Widget build(BuildContext context) {
    final promise = _promise;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('This week'),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: promise == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _GoalSummary(promise: promise),
                const SizedBox(height: AppSpacing.xl),

                const Text('What will you two do?', style: AppTextStyles.headingSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  // Together, and small. The point is that it happens,
                  // not that it is worth something.
                  'Something you can both look forward to — a walk, a story '
                  'at bedtime, cooking together. It only has to be real.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _text,
                  maxLength: 200,
                  maxLines: 3,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'On Saturday we will…',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ElevatedButton(
                  onPressed: _saving ? null : _saveText,
                  child: Text(_saving ? 'Saving…' : 'Save the promise'),
                ),

                const SizedBox(height: AppSpacing.xl),
                const Text('Say something to them',
                    style: AppTextStyles.headingSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  // Says plainly when it will be heard. A parent recording
                  // into a phone deserves to know where it goes.
                  'They will hear this the moment they finish their week — '
                  'not before. In any language. A few seconds is plenty.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                _RecordButton(
                  isRecording: _recording,
                  busy: _saving,
                  hasRecording: promise['has_voice'] as bool? ?? false,
                  onTap: _toggleRecording,
                ),
                if ((promise['has_voice'] as bool? ?? false) && !_recording) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: _playBack,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Hear what you recorded'),
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.coral),
                  ),
                ],
              ],
            ),
    );
  }
}

/// What the child chose, above everything the parent can do.
///
/// First on the screen on purpose. A promise written without looking at
/// the goal reads to a child as though nobody was paying attention, and
/// the parent cannot change what is written here — only answer it.
class _GoalSummary extends StatelessWidget {
  final Map<String, dynamic> promise;
  const _GoalSummary({required this.promise});

  @override
  Widget build(BuildContext context) {
    final kind = promise['goal_kind'] as String?;
    final target = promise['goal_target'] as int? ?? 0;
    final done = promise['goal_done'] as int? ?? 0;
    final complete = promise['goal_is_complete'] as bool? ?? false;

    if (kind == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          // Not a problem to fix. Some weeks a child does not choose, and
          // the app has nothing to say about it.
          'They have not chosen a goal yet this week. You can still leave '
          'them something.',
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    final what = switch (kind) {
      'sounds_found' => 'find $target sounds by listening',
      'sounds_mastered' =>
        target == 1 ? 'wake up a new friend' : 'wake up $target new friends',
      _ => 'practise on $target days',
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: complete
            ? AppColors.coral.withValues(alpha: 0.10)
            : AppColors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            complete ? 'They did it' : 'They chose, themselves, to',
            style: AppTextStyles.label.copyWith(
              color: complete ? AppColors.coral : AppColors.teal,
            ),
          ),
          const SizedBox(height: 2),
          Text(what, style: AppTextStyles.bodyLarge),
          const SizedBox(height: 2),
          Text(
            complete ? 'Finished — $done of $target' : '$done of $target so far',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  final bool isRecording;
  final bool busy;
  final bool hasRecording;
  final VoidCallback onTap;

  const _RecordButton({
    required this.isRecording,
    required this.busy,
    required this.hasRecording,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: busy ? null : onTap,
      icon: Icon(isRecording ? Icons.stop_rounded : Icons.mic_rounded),
      label: Text(
        isRecording
            ? 'Stop'
            : hasRecording
                // Says what it will do before it does it. Re-recording
                // silently over something a parent made is not a thing to
                // spring on them.
                ? 'Record again (replaces the last one)'
                : 'Record a message',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isRecording ? AppColors.coral : AppColors.teal,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
      ),
    );
  }
}
