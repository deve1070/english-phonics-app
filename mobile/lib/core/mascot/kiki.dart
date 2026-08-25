import 'dart:math' as math;

import 'package:flutter/material.dart';

/// What Kiki is doing. Selects which drawing of her is shown.
///
/// The critical rule: **her mood tracks effort, never accuracy.** There is
/// deliberately no "sad" or "disappointed" state. A child who reads aloud
/// and is met with a dejected animal learns that reading makes someone
/// unhappy, and that is precisely how you stop a child practising. A poor
/// attempt gets [encouraging] — leaning in, attentive, ready to go again.
enum KikiMood {
  /// Resting. Standing, alert, waiting.
  idle,

  /// The child is speaking. A wing cupped to her ear.
  listening,

  /// A good attempt. Wings thrown up, beak open.
  celebrating,

  /// A weaker attempt. Leaning in, eyes softly closed, unbothered.
  encouraging,

  /// Thinking / loading. A wing to her chin.
  thinking,
}

/// Kiki, an Abyssinian lovebird (*Agapornis taranta*) — a highland parrot
/// endemic to Ethiopia. Green body, red forehead on the male.
///
/// A parrot is the right mascot for this app specifically because mimicry
/// is the mechanic: the child says a sound, and something repeats it back.
///
/// She is drawn as illustrations rather than with a [CustomPainter]. A
/// vector would stay crisp at any size for a couple of KB, and both are
/// beside the point: as paths the five moods come out near-identical green
/// blobs, so "I am listening to you" and "well done" reach a child as the
/// same picture. Moods a child can tell apart are the entire reason the
/// enum exists.
///
/// So: five illustrations, cut from one character sheet so the bird
/// is the same bird in all of them. They are aligned on her feet and drawn
/// at one shared scale, so changing mood changes her posture and nothing
/// else — a mascot that also changes size or footing reads as a different
/// animal arriving.
///
/// The motion here is deliberately small. The poses carry the meaning; the
/// breathing only stops her looking like a sticker.
class Kiki extends StatefulWidget {
  final double size;
  final KikiMood mood;

  /// Whether she breathes and reacts to mood changes.
  ///
  /// On in the app, always. Golden tests turn it off so their output does
  /// not depend on which frame they happened to stop at.
  ///
  /// Named `animated` and not `animate` for a reason worth keeping: an
  /// instance member shadows an extension member, so a field called
  /// `animate` would quietly capture `flutter_animate`'s `.animate()` at
  /// every call site that wraps her in an effect chain, and each one fails
  /// with a message about invoking a non-function that names neither.
  final bool animated;

  const Kiki({
    super.key,
    this.size = 120,
    this.mood = KikiMood.idle,
    this.animated = true,
  });

  /// Long enough for any reaction she plays to have finished.
  ///
  /// Public so tests that contain her can settle her animations without
  /// having to know how she is built.
  static const Duration settleDelay = Duration(milliseconds: 900);

  static String assetFor(KikiMood mood) =>
      'assets/images/kiki/kiki_${mood.name}.png';

  @override
  State<Kiki> createState() => _KikiState();
}

class _KikiState extends State<Kiki> with TickerProviderStateMixin {
  late final AnimationController _breath;
  late final AnimationController _react;

  @override
  void initState() {
    super.initState();

    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _react = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );

    if (widget.animated) {
      _breath.repeat(reverse: true);
      if (widget.mood != KikiMood.idle) _react.forward();
    }
  }

  @override
  void didUpdateWidget(Kiki old) {
    super.didUpdateWidget(old);
    if (widget.animated && old.mood != widget.mood) {
      _react
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _react.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Decode at the size she is actually shown at. Flutter picks an asset
    // variant from the screen's density alone, so a 46px quest-card Kiki
    // on a 3x phone would otherwise decode the full 384px art and hold
    // half a megabyte to draw a thumbnail. This app targets cheap Android
    // hardware; that is worth one line.
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final decodeTo = (widget.size * ratio).round();

    final image = Image.asset(
      Kiki.assetFor(widget.mood),
      width: widget.size,
      height: widget.size,
      cacheWidth: decodeTo,
      cacheHeight: decodeTo,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );

    if (!widget.animated) {
      return SizedBox(width: widget.size, height: widget.size, child: image);
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_breath, _react]),
        builder: (context, child) {
          final react = Curves.easeOutBack.transform(_react.value.clamp(0, 1));

          // Slow rise and fall so she never looks dead.
          final bob = math.sin(_breath.value * math.pi) * widget.size * 0.015;
          // Celebrating gets a hop on top, spent by the time the reaction
          // finishes — she lands rather than bouncing forever.
          final hop = widget.mood == KikiMood.celebrating
              ? -math.sin(react.clamp(0.0, 1.0) * math.pi) *
                  widget.size *
                  0.075
              : 0.0;

          // A small pop as a mood arrives, so a swap of drawing reads as
          // her reacting rather than as one picture cutting to another.
          final pop = 1.0 + 0.06 * math.sin(react.clamp(0.0, 1.0) * math.pi);

          return Transform.translate(
            offset: Offset(0, bob + hop),
            child: Transform.scale(scale: pop, child: child),
          );
        },
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: image,
        ),
      ),
    );
  }
}
