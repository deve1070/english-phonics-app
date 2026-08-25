import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/entities/lesson_entity.dart';

/// The sound itself: how it is written, and a way to hear it.
///
/// Two things only: the letters, and the button that says them. A sound is
/// taught by hearing it and seeing how it is written.
///
/// The curriculum offers three more — a type badge reading "Alphabet" or
/// "Consonant Blend", a "How to say it" heading, and a description that
/// runs, in full, *"Voiceless labiodental fricative /f/ as in 'fish',
/// written with the letter F."* Nobody aged four to eight can read that
/// sentence, and a child still learning what F looks like certainly cannot.
/// All three are addressed to an adult, and none is shown.
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
    final forms = phoneme.letterForms;

    return Column(
      children: [
        // One line per spelling, so a sound written two ways shows both
        // rather than picking a favourite. Sized to fit rather than
        // measured in characters: "ee EE" and "a A" should look like the
        // same lesson, not two different ones.
        for (final form in forms)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                form,
                style: AppTextStyles.phonemeDisplay.copyWith(
                  color: color,
                  fontSize: 96,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

        const SizedBox(height: AppSpacing.xl),

        // Big enough to be the obvious thing to press, because it is the
        // only thing to press.
        Semantics(
          button: true,
          label: 'Hear the sound',
          child: GestureDetector(
            onTap: isPlayingAudio ? null : onPlayAudio,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: isPlayingAudio ? 28 : 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: isPlayingAudio
                  ? const _PulsingIcon()
                  : const Icon(
                      Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
            ),
          ),
        ).animate().fadeIn(duration: 300.ms).scale(
              begin: const Offset(0.85, 0.85),
              duration: 300.ms,
              curve: Curves.easeOut,
            ),
      ],
    );
  }
}

// ── Pulsing speaker icon while audio plays ───────────────────────
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
          size: 44,
        ),
      ),
    );
  }
}
