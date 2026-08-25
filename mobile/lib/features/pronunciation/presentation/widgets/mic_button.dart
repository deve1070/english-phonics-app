import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class MicButton extends StatelessWidget {
  final bool isRecording;
  final bool isDisabled;
  final VoidCallback onTap;

  const MicButton({
    super.key,
    required this.isRecording,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse ring when recording
          if (isRecording)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.coral.withValues(alpha: 0.15),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .scale(
                  begin: const Offset(1.0, 1.0),
                  end: const Offset(1.4, 1.4),
                  duration: 800.ms,
                  curve: Curves.easeOut,
                )
                .fadeOut(duration: 800.ms),

          // Second pulse ring
          if (isRecording)
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.coral.withValues(alpha: 0.2),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .scale(
                  begin: const Offset(1.0, 1.0),
                  end: const Offset(1.25, 1.25),
                  duration: 800.ms,
                  delay: 200.ms,
                  curve: Curves.easeOut,
                )
                .fadeOut(duration: 800.ms, delay: 200.ms),

          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRecording ? AppColors.coral : AppColors.teal,
              boxShadow: [
                BoxShadow(
                  color: (isRecording ? AppColors.coral : AppColors.teal)
                      .withValues(alpha: 0.45),
                  blurRadius: isRecording ? 24 : 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              isRecording ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Waveform bars animation during recording ──────────────────────
class RecordingWaveform extends StatefulWidget {
  const RecordingWaveform({super.key});

  @override
  State<RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<RecordingWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(12, (i) {
            final phase = (_controller.value + i * 0.1) % 1.0;
            final height = 8 + 28 * (0.5 + 0.5 * (phase * 2 * 3.14159).abs());
            return AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: height.clamp(8.0, 36.0),
              decoration: BoxDecoration(
                color: AppColors.coral.withValues(alpha: 0.7 + 0.3 * phase),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Countdown display ─────────────────────────────────────────────
class CountdownDisplay extends StatelessWidget {
  final int count;

  const CountdownDisplay({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: AppTextStyles.phonemeDisplay.copyWith(
            color: AppColors.coral,
            fontSize: 96,
          ),
        )
            .animate(key: ValueKey(count))
            .scale(
              begin: const Offset(1.5, 1.5),
              end: const Offset(1.0, 1.0),
              duration: 400.ms,
              curve: Curves.elasticOut,
            )
            .fadeIn(duration: 200.ms),
        const Text(
          'Get ready...',
          style: AppTextStyles.bodyMedium,
        ),
      ],
    );
  }
}
