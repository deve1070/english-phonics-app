import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/entities/lesson_entity.dart';

class PhonemeHeroCard extends StatelessWidget {
  final PhonemeEntity phoneme;
  final Color color;
  final bool isPlayingAudio;
  final VoidCallback onPlayAudio;

  const PhonemeHeroCard({
    super.key,
    required this.phoneme,
    required this.color,
    required this.isPlayingAudio,
    required this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.floating,
      ),
      child: Column(
        children: [
          // ── Big letter display ───────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            child: Column(
              children: [
                // The phoneme symbol — huge PatrickHand displaying both cases together
                Text(
                  phoneme.dualCaseSymbol,
                  style: AppTextStyles.phonemeDisplay.copyWith(
                    color: color,
                    fontSize: phoneme.dualCaseSymbol.length > 8 ? 42 : 56, // auto-scale font size if it has helper guides
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 300.ms).scale(
                      begin: const Offset(0.7, 0.7),
                      duration: 400.ms,
                      curve: Curves.elasticOut,
                    ),

                const SizedBox(height: AppSpacing.md),

                // Phoneme type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs + 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                      color: color.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _formatType(phoneme.type),
                    style: AppTextStyles.label.copyWith(color: color),
                  ),
                ).animate(delay: 150.ms).fadeIn(duration: 300.ms),
              ],
            ),
          ),

          // ── Description + audio button ───────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How to say it',
                        style: AppTextStyles.label,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phoneme.description.isNotEmpty
                            ? phoneme.description
                            : 'Listen and repeat the sound',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Audio play button
                GestureDetector(
                  onTap: isPlayingAudio ? null : onPlayAudio,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isPlayingAudio ? color : color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: isPlayingAudio ? 20 : 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: isPlayingAudio
                        ? const _PulsingIcon()
                        : const Icon(
                            Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                  ),
                ).animate(delay: 200.ms).fadeIn(duration: 300.ms).scale(
                      begin: const Offset(0.8, 0.8),
                      duration: 300.ms,
                      curve: Curves.elasticOut,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatType(String type) {
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty
            ? ''
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}

// ── Pulsing speaker icon when audio plays ────────────────────────
class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon();

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
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
      builder: (_, __) => Transform.scale(
        scale: 0.85 + _controller.value * 0.3,
        child: const Icon(
          Icons.graphic_eq_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
