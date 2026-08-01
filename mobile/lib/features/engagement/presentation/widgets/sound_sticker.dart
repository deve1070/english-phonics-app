import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';

/// One collectible: the creature a child earns for mastering a sound.
///
/// Drawn, not downloaded. Ninety phonemes means ninety collectibles, and
/// ninety pieces of artwork is a content project this app does not have —
/// it would also be ninety files to ship to a phone on a slow connection.
/// Instead each creature is derived from its phoneme's id: the same sound
/// always produces the same creature on every device and every install,
/// because the id is the seed and nothing else feeds in.
///
/// The variety comes from combining a few axes rather than from
/// randomness, so no two adjacent sounds look alike but every result is
/// still recognisably from the same family:
///   - silhouette (4)
///   - hue from the app palette (5)
///   - marking (4)
///   - ear/horn shape (3)
/// That is 240 distinct creatures for 90 sounds, drawn from the same
/// flat-fill, hard-shadow language as the rest of the app.
class SoundSticker extends StatelessWidget {
  final int phonemeId;
  final String symbol;
  final bool isUnlocked;

  /// The child knows this sound by sight but cannot yet say it — the
  /// recognition track's own reward. The creature opens its eyes and
  /// stays grey, so the shelf shows the two skills as two stages instead
  /// of letting either stand in for the other. A child who is good at
  /// listening sees that recognised, and still has somewhere to go.
  final bool isRecognised;
  final double size;

  const SoundSticker({
    super.key,
    required this.phonemeId,
    required this.symbol,
    required this.isUnlocked,
    this.isRecognised = false,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StickerPainter(
          seed: phonemeId,
          isUnlocked: isUnlocked,
          isAwake: isUnlocked || isRecognised,
          // Sleeping creatures show no symbol. The shape alone is the
          // tease: the child can see there is something there without
          // being told what, which is what makes the gap worth closing.
          // Once they can pick the symbol out by ear it is no longer a
          // secret, so it goes on the badge even before the sound is
          // sayable.
          symbol: (isUnlocked || isRecognised) ? symbol : null,
          symbolStyle: AppTextStyles.headingSmall.copyWith(
            fontSize: size * 0.24,
            color: AppColors.ink,
            height: 1,
          ),
        ),
      ),
    );
  }
}

const List<Color> _hues = [
  AppColors.leaf,
  AppColors.sky,
  AppColors.honey,
  AppColors.level4,
  AppColors.crest,
];

/// The four axes a creature is built from, derived from its phoneme id.
///
/// Public and separate from the painter so the thing that actually
/// matters — that neighbouring sounds do not get near-identical
/// creatures — can be asserted rather than only eyeballed in a golden.
class StickerTraits {
  final int hue;
  final int silhouette;
  final int crown;
  final int marking;

  const StickerTraits({
    required this.hue,
    required this.silhouette,
    required this.crown,
    required this.marking,
  });

  /// Every axis turns over inside a run of five, because five is a lesson.
  /// Phoneme ids are consecutive within a lesson, so an axis with a slower
  /// stride hands the whole lesson one shape — the first attempt here did
  /// exactly that and the results looked like a printing error. Colour
  /// reads fastest, since colour is what the eye sorts on.
  factory StickerTraits.forPhoneme(int phonemeId) => StickerTraits(
        hue: phonemeId % _hues.length,
        silhouette: (phonemeId ~/ 2) % 4,
        crown: (phonemeId ~/ 3) % 3,
        marking: (phonemeId ~/ 4) % 4,
      );

  /// Total number of distinct creatures the system can produce.
  static const int variants = 5 * 4 * 3 * 4;

  @override
  bool operator ==(Object other) =>
      other is StickerTraits &&
      other.hue == hue &&
      other.silhouette == silhouette &&
      other.crown == crown &&
      other.marking == marking;

  @override
  int get hashCode => Object.hash(hue, silhouette, crown, marking);

  @override
  String toString() => 'StickerTraits($hue,$silhouette,$crown,$marking)';
}

class _StickerPainter extends CustomPainter {
  final int seed;
  final bool isUnlocked;
  final bool isAwake;
  final String? symbol;
  final TextStyle symbolStyle;

  _StickerPainter({
    required this.seed,
    required this.isUnlocked,
    required this.isAwake,
    required this.symbol,
    required this.symbolStyle,
  });

  StickerTraits get _traits => StickerTraits.forPhoneme(seed);
  int get _silhouette => _traits.silhouette;
  int get _marking => _traits.marking;
  int get _crown => _traits.crown;

  Color get _hue => _hues[_traits.hue];
  Color get _body => isUnlocked ? _hue : AppColors.dormant;
  Color get _belly => isUnlocked
      ? Color.lerp(_hue, AppColors.surface, 0.72)!
      : Color.lerp(AppColors.dormant, AppColors.surface, 0.6)!;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Sized so the tallest crown (the antenna) still clears the top edge
    // and the widest silhouette clears the sides, with the name badge
    // sitting below everything.
    final centre = Offset(w / 2, h * 0.47);
    final radius = w * 0.28;

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.ink;

    // The four silhouettes are pushed apart deliberately — tall, wide,
    // round, boxy. Subtle variation reads as one creature drawn slightly
    // wrong four times; only obvious difference reads as four creatures.
    final body = Path();
    switch (_silhouette) {
      case 0: // round
        body.addOval(Rect.fromCircle(center: centre, radius: radius));
      case 1: // tall and narrow
        body.addOval(Rect.fromCenter(
          center: centre,
          width: radius * 1.5,
          height: radius * 2.4,
        ));
      case 2: // wide, flat-bottomed
        body.addRRect(RRect.fromRectAndCorners(
          Rect.fromCenter(
            center: centre,
            width: radius * 2.4,
            height: radius * 1.6,
          ),
          topLeft: Radius.circular(radius * 0.8),
          topRight: Radius.circular(radius * 0.8),
          bottomLeft: Radius.circular(radius * 0.3),
          bottomRight: Radius.circular(radius * 0.3),
        ));
      default: // boxy pebble
        body.addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: centre,
            width: radius * 2.0,
            height: radius * 2.0,
          ),
          Radius.circular(radius * 0.5),
        ));
    }

    _paintCrown(canvas, centre, radius, outline);

    // Hard offset shadow, no blur — same rule as every other surface in
    // the app. See AppShadows.
    canvas.drawPath(
      body.shift(Offset(w * 0.035, h * 0.035)),
      Paint()..color = AppColors.ink.withValues(alpha: 0.18),
    );
    canvas.drawPath(body, Paint()..color = _body);

    canvas.save();
    canvas.clipPath(body);
    _paintBelly(canvas, centre, radius);
    _paintMarking(canvas, centre, radius);
    canvas.restore();

    canvas.drawPath(body, outline);
    _paintFace(canvas, centre, radius, w);
    _paintSymbol(canvas, size);
  }

  void _paintCrown(Canvas canvas, Offset c, double r, Paint outline) {
    // Drawn before the body so it tucks behind it rather than floating.
    final fill = Paint()..color = _body;
    switch (_crown) {
      case 0: // two ears
        for (final dx in [-r * 0.52, r * 0.52]) {
          final ear = Path()
            ..addOval(Rect.fromCircle(
              center: Offset(c.dx + dx, c.dy - r * 0.82),
              radius: r * 0.32,
            ));
          canvas.drawPath(ear, fill);
          canvas.drawPath(ear, outline);
        }
      case 1: // single antenna
        canvas.drawLine(
          Offset(c.dx, c.dy - r * 0.9),
          Offset(c.dx, c.dy - r * 1.28),
          outline,
        );
        final tip = Path()
          ..addOval(Rect.fromCircle(
            center: Offset(c.dx, c.dy - r * 1.3),
            radius: r * 0.18,
          ));
        canvas.drawPath(tip, fill);
        canvas.drawPath(tip, outline);
      default: // tuft
        final tuft = Path()
          ..moveTo(c.dx - r * 0.36, c.dy - r * 0.85)
          ..lineTo(c.dx, c.dy - r * 1.38)
          ..lineTo(c.dx + r * 0.36, c.dy - r * 0.85)
          ..close();
        canvas.drawPath(tuft, fill);
        canvas.drawPath(tuft, outline);
    }
  }

  void _paintBelly(Canvas canvas, Offset c, double r) {
    // Small and low. A belly patch covering most of the body swamped the
    // silhouette and made every creature read as the same pale shape.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + r * 0.62),
        width: r * 1.05,
        height: r * 0.8,
      ),
      Paint()..color = _belly,
    );
  }

  void _paintMarking(Canvas canvas, Offset c, double r) {
    // Strong enough to survive being 76px on a cheap screen. At the
    // opacity this started on the markings were invisible, which threw
    // away a quarter of the variety for nothing.
    final paint = Paint()..color = AppColors.ink.withValues(alpha: 0.20);
    switch (_marking) {
      case 0: // spots across the shoulders
        for (var i = 0; i < 3; i++) {
          final angle = -2.5 + i * 0.7;
          canvas.drawCircle(
            Offset(c.dx + math.cos(angle) * r * 0.72,
                c.dy + math.sin(angle) * r * 0.72),
            r * 0.15,
            paint,
          );
        }
      case 1: // vertical stripes
        for (var i = -1; i <= 1; i++) {
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(c.dx + i * r * 0.62, c.dy),
              width: r * 0.22,
              height: r * 3,
            ),
            paint,
          );
        }
      case 2: // a band across the middle
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(c.dx, c.dy + r * 0.15),
            width: r * 3,
            height: r * 0.34,
          ),
          paint,
        );
      default: // plain — some creatures are simply plain
        break;
    }
  }

  void _paintFace(Canvas canvas, Offset c, double r, double w) {
    final eye = Paint()..color = AppColors.ink;
    // A locked creature is asleep, not dead: closed eyes read as "not yet",
    // where a blank face reads as absence. The distinction matters on a
    // shelf a child is looking at every day.
    //
    // Eyes open on recognition, colour comes with saying it. A grey
    // creature looking back at the child is the in-between state, and it
    // is the one most of the shelf will be in for a long while.
    if (isAwake) {
      for (final dx in [-r * 0.28, r * 0.28]) {
        canvas.drawCircle(Offset(c.dx + dx, c.dy - r * 0.18), r * 0.11, eye);
      }
    } else {
      final lid = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.03
        ..strokeCap = StrokeCap.round
        ..color = AppColors.ink.withValues(alpha: 0.55);
      for (final dx in [-r * 0.28, r * 0.28]) {
        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(c.dx + dx, c.dy - r * 0.22),
            radius: r * 0.16,
          ),
          0.25,
          math.pi - 0.5,
          false,
          lid,
        );
      }
    }
  }

  void _paintSymbol(Canvas canvas, Size size) {
    final text = symbol;
    if (text == null) return;
    final painter = TextPainter(
      text: TextSpan(text: text, style: symbolStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '',
    )..layout(maxWidth: size.width * 0.8);

    // On a badge at the foot of the creature rather than across its face,
    // so the symbol stays legible whatever colour the body came out.
    final centre = Offset(size.width / 2, size.height * 0.90);
    final badge = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: centre,
        width: painter.width + size.width * 0.16,
        height: painter.height + size.height * 0.07,
      ),
      Radius.circular(AppRadius.sm),
    );
    canvas.drawRRect(badge, Paint()..color = AppColors.surface);
    canvas.drawRRect(
      badge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.028
        ..color = AppColors.ink,
    );
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_StickerPainter old) =>
      old.seed != seed ||
      old.isUnlocked != isUnlocked ||
      old.isAwake != isAwake ||
      old.symbol != symbol;
}
