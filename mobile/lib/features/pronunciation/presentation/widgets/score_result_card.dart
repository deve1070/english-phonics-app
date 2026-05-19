import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../cubit/pronunciation_state.dart';

class ScoreResultCard extends StatelessWidget {
  final PronunciationScored state;
  final VoidCallback onTryAgain;
  final VoidCallback onNext;

  const ScoreResultCard({
    super.key,
    required this.state,
    required this.onTryAgain,
    required this.onNext,
  });

  Color get _scoreColor {
    if (state.score >= 90) return AppColors.green;
    if (state.score >= 80) return AppColors.teal;
    if (state.score >= 60) return AppColors.yellow;
    return AppColors.coral;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.floating,
      ),
      child: Column(
        children: [
          // Mascot reaction
          Image.asset(
            state.mascotAsset,
            height: 120,
            errorBuilder: (_, __, ___) => Text(
              state.isCompleted ? '🎉' : '😊',
              style: const TextStyle(fontSize: 72),
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.5, 0.5),
                duration: 600.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 300.ms),

          const SizedBox(height: AppSpacing.md),

          // Grade label
          Text(
            state.grade,
            style: AppTextStyles.displaySmall.copyWith(color: _scoreColor),
            textAlign: TextAlign.center,
          )
              .animate(delay: 300.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.3, end: 0, duration: 400.ms),

          const SizedBox(height: AppSpacing.lg),

          // Score ring
          _ScoreRing(score: state.score, color: _scoreColor)
              .animate(delay: 400.ms)
              .fadeIn(duration: 400.ms),

          const SizedBox(height: AppSpacing.lg),

          // Pass/fail message
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: _scoreColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: _scoreColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Text(
              state.isCompleted
                  ? '✅ Exercise completed!'
                  : '🎯 Score 80 or more to complete',
              style: AppTextStyles.bodyMedium.copyWith(
                color: _scoreColor,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ).animate(delay: 500.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: AppSpacing.xl),

          // Action buttons
          Row(
            children: [
              // Try again
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onTryAgain,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try Again'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.coral,
                    side: const BorderSide(color: AppColors.coral, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    minimumSize: const Size(0, AppSizes.minTouchTarget),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Next exercise
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _scoreColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    minimumSize: const Size(0, AppSizes.minTouchTarget),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ).animate(delay: 600.ms).fadeIn(duration: 400.ms),
        ],
      ),
    );
  }
}

// ── Animated score ring ───────────────────────────────────────────
class _ScoreRing extends StatefulWidget {
  final double score;
  final Color color;

  const _ScoreRing({required this.score, required this.color});

  @override
  State<_ScoreRing> createState() => _ScoreRingState();
}

class _ScoreRingState extends State<_ScoreRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progressAnim = Tween<double>(begin: 0, end: widget.score / 100).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressAnim,
      builder: (_, __) => SizedBox(
        width: 140,
        height: 140,
        child: CustomPaint(
          painter: _RingPainter(
            progress: _progressAnim.value,
            color: widget.color,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(widget.score * _progressAnim.value / (widget.score / 100)).toInt()}',
                  style: AppTextStyles.scoreDisplay.copyWith(
                    color: widget.color,
                    fontSize: 48,
                  ),
                ),
                Text(
                  'out of 100',
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;
    const strokeWidth = 12.0;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withOpacity(0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
