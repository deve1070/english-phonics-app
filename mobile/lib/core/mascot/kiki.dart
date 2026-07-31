import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// What Kiki is doing. Drives posture, eyes, wings and beak.
///
/// The critical rule: **her mood tracks effort, never accuracy.** There is
/// deliberately no "sad" or "disappointed" state. A child who reads aloud
/// and is met with a dejected animal learns that reading makes someone
/// unhappy, and that is precisely how you stop a child practising. A poor
/// attempt gets [encouraging] — leaning in, attentive, ready to go again.
enum KikiMood {
  /// Resting. Blinks, breathes.
  idle,

  /// The child is speaking. Head cocked, listening hard.
  listening,

  /// A good attempt. Wings up, hopping.
  celebrating,

  /// A weaker attempt. Warm, attentive, unbothered.
  encouraging,

  /// Thinking / loading.
  thinking,
}

/// Kiki, an Abyssinian lovebird (*Agapornis taranta*) — a highland parrot
/// endemic to Ethiopia. Green body, red forehead on the male.
///
/// A parrot is the right mascot for this app specifically because mimicry
/// is the mechanic: the child says a sound, and something repeats it back.
///
/// She is drawn with [CustomPainter] rather than shipped as an image. That
/// buys four things at once: she stays crisp at any size, expressions are a
/// parameter instead of one sprite per mood, she adds a couple of KB rather
/// than a sprite sheet, and vector fills render cheaply on the low-end
/// Android hardware this app targets.
class Kiki extends StatefulWidget {
  final double size;
  final KikiMood mood;

  /// Blinking is deliberately irregular — the irregularity is what sells
  /// her as alive — which makes any rendering of her non-deterministic.
  /// Golden tests turn it off so their output is stable; nothing in the
  /// app should.
  final bool blink;

  const Kiki({
    super.key,
    this.size = 120,
    this.mood = KikiMood.idle,
    this.blink = true,
  });

  /// Shortest possible gap before she blinks.
  ///
  /// Public so golden tests that contain her can settle their own
  /// animations without crossing into blink territory and going flaky.
  /// Every reaction she plays finishes well inside this.
  static const Duration minBlinkDelay = Duration(milliseconds: 1800);

  @override
  State<Kiki> createState() => _KikiState();
}

class _KikiState extends State<Kiki> with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _blink;
  late final AnimationController _react;

  /// Held so it can be cancelled. A self-rescheduling Future.delayed would
  /// outlive the widget, which leaks and hangs any test that pumps her.
  Timer? _blinkTimer;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();

    // Slow breathing/bobbing so she never looks like a dead sticker.
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    // Blinks are a separate, much faster controller driven on a timer via
    // status callbacks — tying them to the breath would make her blink
    // rhythmically, which reads as mechanical rather than alive.
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    if (widget.blink) _scheduleBlink();

    _react = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    if (widget.mood != KikiMood.idle) _react.forward();
  }

  void _scheduleBlink() {
    // Irregular interval: the irregularity is what sells it.
    final ms = Kiki.minBlinkDelay.inMilliseconds + _random.nextInt(3200);
    _blinkTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      _blink.forward().then((_) {
        if (mounted) _blink.reverse();
      });
      _scheduleBlink();
    });
  }

  @override
  void didUpdateWidget(Kiki old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) {
      _react
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _idle.dispose();
    _blink.dispose();
    _react.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _blink, _react]),
        builder: (context, _) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _KikiPainter(
              mood: widget.mood,
              breath: _idle.value,
              blink: _blink.value,
              react: Curves.easeOutBack.transform(_react.value.clamp(0, 1)),
            ),
          );
        },
      ),
    );
  }
}

class _KikiPainter extends CustomPainter {
  final KikiMood mood;

  /// 0..1 breathing cycle.
  final double breath;

  /// 0..1 eyelid closure.
  final double blink;

  /// 0..1 progress into the current mood.
  final double react;

  _KikiPainter({
    required this.mood,
    required this.breath,
    required this.blink,
    required this.react,
  });

  // Plumage. Kept local rather than semantic: these describe the bird, not
  // UI state, so they should not shift if the semantic palette is retuned.
  static const _body = AppColors.leaf;
  static const _bodyDark = AppColors.leafDark;
  static const _belly = Color(0xFF6FAE7C);
  static const _forehead = AppColors.crest;
  static const _beak = Color(0xFFE8A33C);
  static const _outline = AppColors.ink;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(size.width / 2, size.height / 2);

    // Gentle vertical bob, amplified while celebrating.
    final bobBase = math.sin(breath * math.pi) * s * 0.015;
    final hop = mood == KikiMood.celebrating
        ? -math.sin(react * math.pi * 2).abs() * s * 0.07
        : 0.0;
    canvas.save();
    canvas.translate(0, bobBase + hop);

    // Head tilts when listening — the single clearest "I am paying
    // attention to you" cue an animal shape can give. Generous angles:
    // subtle tilts vanish at the sizes this is actually shown.
    final tilt = switch (mood) {
      KikiMood.listening => -0.34 * react,
      KikiMood.thinking => 0.26 * react,
      KikiMood.encouraging => -0.16 * react,
      _ => 0.0,
    };

    final stroke = Paint()
      ..color = _outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.035
      ..strokeJoin = StrokeJoin.round;

    _drawTail(canvas, c, s, stroke);
    _drawBody(canvas, c, s, stroke);
    _drawWing(canvas, c, s, stroke);

    canvas.save();
    // Rotate the head about the neck, not the canvas centre.
    final neck = Offset(c.dx, c.dy - s * 0.06);
    canvas.translate(neck.dx, neck.dy);
    canvas.rotate(tilt);
    canvas.translate(-neck.dx, -neck.dy);
    _drawHead(canvas, c, s, stroke);
    canvas.restore();

    canvas.restore();
  }

  void _drawBody(Canvas canvas, Offset c, double s, Paint stroke) {
    // Body is a teardrop, narrow at the shoulders and full at the base, so
    // there is a readable neck instead of two stacked circles.
    final top = c.dy + s * 0.02;
    final bottom = c.dy + s * 0.42;
    final halfW = s * 0.25;
    final body = Path()
      ..moveTo(c.dx - halfW * 0.62, top)
      ..cubicTo(
        c.dx - halfW * 1.05, top + s * 0.10,
        c.dx - halfW * 1.08, bottom - s * 0.06,
        c.dx, bottom,
      )
      ..cubicTo(
        c.dx + halfW * 1.08, bottom - s * 0.06,
        c.dx + halfW * 1.05, top + s * 0.10,
        c.dx + halfW * 0.62, top,
      )
      ..close();
    canvas.drawPath(body, Paint()..color = _body);

    // Lighter breast gives form without a gradient. Clipped so it can sit
    // flush against the silhouette edge.
    canvas.save();
    canvas.clipPath(body);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx - s * 0.04, c.dy + s * 0.26),
        width: s * 0.30,
        height: s * 0.36,
      ),
      Paint()..color = _belly,
    );
    canvas.restore();
    canvas.drawPath(body, stroke);

    final feet = Paint()
      ..color = _beak
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.034
      ..strokeCap = StrokeCap.round;
    for (final dx in [-0.08, 0.08]) {
      canvas.drawLine(
        Offset(c.dx + s * dx, c.dy + s * 0.40),
        Offset(c.dx + s * dx, c.dy + s * 0.47),
        feet,
      );
    }
  }

  void _drawTail(Canvas canvas, Offset c, double s, Paint stroke) {
    // A long swept tail, angled down-left, so the silhouette is obviously a
    // bird rather than a ball. Drawn before the body so it tucks behind.
    final root = Offset(c.dx - s * 0.10, c.dy + s * 0.24);
    final tail = Path()
      ..moveTo(root.dx, root.dy - s * 0.06)
      ..lineTo(root.dx - s * 0.40, root.dy + s * 0.20)
      ..lineTo(root.dx - s * 0.36, root.dy + s * 0.05)
      ..lineTo(root.dx - s * 0.30, root.dy + s * 0.14)
      ..lineTo(root.dx - s * 0.24, root.dy - s * 0.01)
      ..lineTo(root.dx, root.dy + s * 0.10)
      ..close();
    canvas.drawPath(tail, Paint()..color = _bodyDark);
    canvas.drawPath(tail, stroke);
  }

  void _drawWing(Canvas canvas, Offset c, double s, Paint stroke) {
    // Wing throws right open when celebrating. It sits on the silhouette
    // edge and is leaf-shaped, so it can't be mistaken for a belly patch.
    // Negative rotation swings the tip up and *away* from the body. The
    // opposite sign sweeps it across her belly, which reads as a pod stuck
    // to her chest rather than a raised wing.
    final lift = mood == KikiMood.celebrating ? -1.30 * react : 0.0;

    canvas.save();
    final pivot = Offset(c.dx + s * 0.16, c.dy + s * 0.10);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(lift);
    canvas.translate(-pivot.dx, -pivot.dy);

    final wing = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..quadraticBezierTo(
        pivot.dx + s * 0.20, pivot.dy + s * 0.10,
        pivot.dx + s * 0.06, pivot.dy + s * 0.28,
      )
      ..quadraticBezierTo(
        pivot.dx - s * 0.06, pivot.dy + s * 0.16,
        pivot.dx, pivot.dy,
      )
      ..close();
    canvas.drawPath(wing, Paint()..color = _bodyDark);
    canvas.drawPath(wing, stroke);
    canvas.restore();
  }

  void _drawHead(Canvas canvas, Offset c, double s, Paint stroke) {
    // Deliberately large relative to the body. Juvenile proportions — big
    // head, big eyes — are what make a character read as friendly to a
    // small child rather than as an accurate bird.
    final headC = Offset(c.dx, c.dy - s * 0.20);
    final head = Path()
      ..addOval(Rect.fromCenter(
        center: headC,
        width: s * 0.58,
        height: s * 0.54,
      ));
    canvas.drawPath(head, Paint()..color = _body);

    // The red forehead patch — the field mark that makes her this species
    // rather than a generic green bird. Clipped to the skull, with a curved
    // lower edge so it reads as plumage rather than a beret.
    canvas.save();
    canvas.clipPath(head);
    final patch = Path()
      ..moveTo(headC.dx - s * 0.32, headC.dy - s * 0.15)
      ..quadraticBezierTo(
        headC.dx, headC.dy - s * 0.03,
        headC.dx + s * 0.32, headC.dy - s * 0.15,
      )
      ..lineTo(headC.dx + s * 0.32, headC.dy - s * 0.34)
      ..lineTo(headC.dx - s * 0.32, headC.dy - s * 0.34)
      ..close();
    canvas.drawPath(patch, Paint()..color = _forehead);
    canvas.restore();
    canvas.drawPath(head, stroke);

    _drawEye(canvas, Offset(headC.dx - s * 0.115, headC.dy + s * 0.06), s);
    _drawEye(canvas, Offset(headC.dx + s * 0.115, headC.dy + s * 0.06), s);
    _drawBeak(canvas, headC, s, stroke);
  }

  void _drawEye(Canvas canvas, Offset at, double s) {
    final open = (1 - blink).clamp(0.0, 1.0);
    // Eyes widen slightly when celebrating, narrow a touch when thinking.
    final scale = switch (mood) {
      KikiMood.celebrating => 1.0 + 0.16 * react,
      KikiMood.thinking => 1.0 - 0.22 * react,
      _ => 1.0,
    };
    final r = s * 0.058 * scale;

    if (open < 0.12) {
      // Closed: a short arc reads far better than a flat line.
      final p = Paint()
        ..color = _outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.022
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCenter(center: at, width: r * 2.2, height: r * 1.6),
        math.pi * 0.15,
        math.pi * 0.7,
        false,
        p,
      );
      return;
    }

    canvas.drawOval(
      Rect.fromCenter(center: at, width: r * 2, height: r * 2 * open),
      Paint()..color = _outline,
    );
    // Catchlight. Small, but it is the difference between alive and glassy.
    canvas.drawCircle(
      Offset(at.dx + r * 0.32, at.dy - r * 0.34 * open),
      r * 0.32,
      Paint()..color = Colors.white.withValues(alpha: 0.95 * open),
    );
  }

  void _drawBeak(Canvas canvas, Offset headC, double s, Paint stroke) {
    // Open beak while she is listening or cheering — she is vocal, and this
    // is the app's whole subject.
    final openAmt = switch (mood) {
      KikiMood.celebrating => 0.85 * react,
      KikiMood.listening => 0.45 * react,
      _ => 0.0,
    };

    final top = Offset(headC.dx, headC.dy + s * 0.155);
    final upper = Path()
      ..moveTo(top.dx - s * 0.075, top.dy)
      ..quadraticBezierTo(top.dx, top.dy + s * 0.13, top.dx + s * 0.075, top.dy)
      ..close();
    canvas.drawPath(upper, Paint()..color = _beak);
    canvas.drawPath(upper, stroke);

    if (openAmt > 0.02) {
      final drop = s * 0.085 * openAmt;
      final lower = Path()
        ..moveTo(top.dx - s * 0.055, top.dy + s * 0.07)
        ..quadraticBezierTo(
          top.dx,
          top.dy + s * 0.07 + drop,
          top.dx + s * 0.055,
          top.dy + s * 0.07,
        )
        ..close();
      canvas.drawPath(lower, Paint()..color = const Color(0xFFB9762A));
      canvas.drawPath(lower, stroke);
    }
  }

  @override
  bool shouldRepaint(_KikiPainter old) =>
      old.mood != mood ||
      old.breath != breath ||
      old.blink != blink ||
      old.react != react;
}
