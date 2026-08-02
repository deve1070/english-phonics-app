import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/engagement_models.dart';

/// The prize for keeping a week's promise.
///
/// Drawn from the week it belongs to, so a given week always produces the
/// same medal on every device — which is what lets the app show a child
/// on Monday the exact object they are working towards, greyed out, and
/// hand them that same object on Friday. A surprise prize is a payment;
/// a prize you can see from the start is something to aim at.
///
/// The face carries the goal the child chose, not a score. That is the
/// point of the whole shelf: looking along it, a child sees *what they
/// decided to do* week after week — came every day, went listening, woke
/// friends up — rather than a row of identical tokens that only says how
/// many times they complied.
class WeekMedal extends StatelessWidget {
  final DateTime weekStart;

  /// What the week was spent on. Null on a medal not yet earned, where
  /// the face is left blank because the child has not chosen yet.
  final GoalKind? kind;

  /// A medal not yet won is drawn in full, in grey. Hiding it would leave
  /// the child working towards nothing they can picture.
  final bool isEarned;
  final double size;

  const WeekMedal({
    super.key,
    required this.weekStart,
    required this.kind,
    required this.isEarned,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MedalPainter(
          traits: MedalTraits.forWeek(weekStart),
          kind: kind,
          isEarned: isEarned,
        ),
      ),
    );
  }
}

/// The prize with the week's progress showing through it.
///
/// Grey underneath, colour on top, clipped to how far along the week is.
/// One object doing two jobs — the thing being worked towards and the
/// record of the work — which is a good deal more legible to a six-year-old
/// than a bar with a percentage on it.
///
/// The clip is a real rectangle over the full-size medal rather than an
/// [Align] with a heightFactor: an Align shrinks its own box and re-centres
/// it, which slides the coloured half out of register with the grey one.
///
/// Colour rises through the disc rather than through the whole picture.
/// Mapped over the full height the disc fills by about two thirds of the
/// way and the last stretch of the week shows no change at all — a child
/// doing the hardest part of the work and watching nothing happen. Over
/// the disc alone every step moves it, and the ribbon taking colour is
/// what marks the week actually kept.
class FillingMedal extends StatelessWidget {
  final DateTime weekStart;
  final GoalKind? kind;

  /// 0 to 1. At 0 nothing is drawn over the grey; at 1 the medal is whole.
  final double fraction;
  final double size;

  const FillingMedal({
    super.key,
    required this.weekStart,
    required this.kind,
    required this.fraction,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    final filled = fraction.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          WeekMedal(
            weekStart: weekStart,
            kind: kind,
            isEarned: false,
            size: size,
          ),
          if (filled > 0)
            ClipRect(
              clipper: _RisingFrom(filled),
              child: WeekMedal(
                weekStart: weekStart,
                kind: kind,
                isEarned: true,
                size: size,
              ),
            ),
        ],
      ),
    );
  }
}

/// How much of the picture the disc occupies, top and bottom as a share of
/// the height. Kept next to the painter that draws it — if either moves
/// without the other, the colour stops rising through the disc.
const double _discTop = _discCentreY - _discRadius;
const double _discBottom = _discCentreY + _discRadius;

/// The bottom [fraction] of the disc, so colour rises as the week goes.
/// A complete week takes the whole picture, ribbon included.
class _RisingFrom extends CustomClipper<Rect> {
  final double fraction;
  const _RisingFrom(this.fraction);

  @override
  Rect getClip(Size size) {
    if (fraction >= 1) return Offset.zero & size;
    final top = _discBottom - fraction * (_discBottom - _discTop);
    return Rect.fromLTRB(0, size.height * top, size.width, size.height);
  }

  @override
  bool shouldReclip(_RisingFrom old) => old.fraction != fraction;
}

// Where the disc sits in the square, as shares of the height and width.
// The ribbon hangs above it, so the disc is low rather than centred.
const double _discCentreY = 0.62;
const double _discRadius = 0.28;

const List<Color> _ribbons = [
  AppColors.crest,
  AppColors.sky,
  AppColors.leaf,
  AppColors.level4,
  AppColors.honey,
];

/// What makes one week's medal different from the next one's.
///
/// Public and separate from the painter so the property that matters —
/// that consecutive weeks look clearly unalike, since they will sit next
/// to each other on the shelf — can be asserted rather than eyeballed.
class MedalTraits {
  final int ribbon;
  final int pattern;

  const MedalTraits({required this.ribbon, required this.pattern});

  /// Weeks since the epoch, which is a plain increasing integer and
  /// therefore gives neighbouring weeks different values on both axes.
  static int weekNumber(DateTime weekStart) =>
      weekStart.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay ~/ 7;

  factory MedalTraits.forWeek(DateTime weekStart) {
    final n = weekNumber(weekStart);
    return MedalTraits(ribbon: n % _ribbons.length, pattern: (n ~/ 2) % 3);
  }

  static const int variants = 5 * 3;

  @override
  bool operator ==(Object other) =>
      other is MedalTraits && other.ribbon == ribbon && other.pattern == pattern;

  @override
  int get hashCode => Object.hash(ribbon, pattern);

  @override
  String toString() => 'MedalTraits($ribbon,$pattern)';
}

class _MedalPainter extends CustomPainter {
  final MedalTraits traits;
  final GoalKind? kind;
  final bool isEarned;

  _MedalPainter({
    required this.traits,
    required this.kind,
    required this.isEarned,
  });

  Color get _ribbon =>
      isEarned ? _ribbons[traits.ribbon] : AppColors.dormant;
  Color get _disc => isEarned ? AppColors.honey : AppColors.dormant;
  Color get _face => isEarned
      ? Color.lerp(AppColors.honey, AppColors.surface, 0.55)!
      : Color.lerp(AppColors.dormant, AppColors.surface, 0.5)!;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centre = Offset(w / 2, h * _discCentreY);
    final radius = w * _discRadius;

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.ink;

    _paintRibbon(canvas, size, centre, radius, outline);

    // Hard offset shadow, no blur — the same rule as every other surface
    // in the app. See AppShadows.
    canvas.drawCircle(
      centre + Offset(w * 0.035, h * 0.03),
      radius,
      Paint()..color = AppColors.ink.withValues(alpha: 0.18),
    );
    canvas.drawCircle(centre, radius, Paint()..color = _disc);
    canvas.drawCircle(centre, radius * 0.74, Paint()..color = _face);
    canvas.drawCircle(centre, radius, outline);

    _paintKindGlyph(canvas, centre, radius);
  }

  void _paintRibbon(
      Canvas canvas, Size size, Offset c, double r, Paint outline) {
    // Two bands from the top edge, tucked behind the disc so it reads as
    // hanging from them rather than sitting on top of them.
    final fill = Paint()..color = _ribbon;
    var bands = Path();
    for (final dir in [-1.0, 1.0]) {
      final band = Path()
        ..moveTo(c.dx + dir * r * 0.75, 0)
        ..lineTo(c.dx + dir * r * 0.12, c.dy)
        ..lineTo(c.dx - dir * r * 0.20, c.dy)
        ..lineTo(c.dx + dir * r * 0.30, 0)
        ..close();
      canvas.drawPath(band, fill);
      canvas.drawPath(band, outline);
      bands = Path.combine(PathOperation.union, bands, band);
    }

    if (traits.pattern == 0) return; // plain

    // Clipped to the bands themselves, not just to the space above the
    // disc. Without this the stripes and chevrons run out across the bare
    // background either side, which reads as damage rather than pattern.
    canvas.save();
    canvas.clipPath(bands);
    final mark = Paint()..color = AppColors.ink.withValues(alpha: 0.22);
    if (traits.pattern == 1) {
      // Stripes across both bands.
      for (var y = size.height * 0.06; y < c.dy; y += size.height * 0.13) {
        canvas.drawRect(
          Rect.fromLTWH(0, y, size.width, size.height * 0.045),
          mark,
        );
      }
    } else {
      // Chevrons, which read differently from stripes even at 40px.
      for (var y = size.height * 0.04; y < c.dy; y += size.height * 0.16) {
        final chevron = Path()
          ..moveTo(c.dx - r, y)
          ..lineTo(c.dx, y + size.height * 0.07)
          ..lineTo(c.dx + r, y)
          ..lineTo(c.dx + r, y + size.height * 0.045)
          ..lineTo(c.dx, y + size.height * 0.115)
          ..lineTo(c.dx - r, y + size.height * 0.045)
          ..close();
        canvas.drawPath(chevron, mark);
      }
    }
    canvas.restore();
  }

  void _paintKindGlyph(Canvas canvas, Offset c, double r) {
    final goal = kind;
    if (goal == null) return;

    final ink = Paint()
      ..color = isEarned ? AppColors.ink : AppColors.ink.withValues(alpha: 0.35);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.14
      ..strokeCap = StrokeCap.round
      ..color = ink.color;

    switch (goal) {
      case GoalKind.days:
        // Days in a row, as a row.
        for (var i = -1; i <= 1; i++) {
          canvas.drawCircle(Offset(c.dx + i * r * 0.34, c.dy), r * 0.13, ink);
        }
      case GoalKind.soundsFound:
        // A sound arriving: arcs opening to the right.
        for (var i = 1; i <= 3; i++) {
          canvas.drawArc(
            Rect.fromCircle(center: Offset(c.dx - r * 0.4, c.dy), radius: r * 0.22 * i),
            -0.7,
            1.4,
            false,
            stroke,
          );
        }
      case GoalKind.soundsMastered:
        // A star: the one shape a five-year-old already reads as "well done".
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final angle = -math.pi / 2 + i * math.pi / 5;
          final radius = i.isEven ? r * 0.48 : r * 0.20;
          final point = Offset(
            c.dx + math.cos(angle) * radius,
            c.dy + math.sin(angle) * radius,
          );
          i == 0 ? star.moveTo(point.dx, point.dy) : star.lineTo(point.dx, point.dy);
        }
        star.close();
        canvas.drawPath(star, ink);
    }
  }

  @override
  bool shouldRepaint(_MedalPainter old) =>
      old.traits != traits || old.kind != kind || old.isEarned != isEarned;
}
