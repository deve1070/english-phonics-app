import 'package:flutter/material.dart';

import 'app_colors.dart';

/// A woven geometric band, in the spirit of *tibeb* — the patterned edging
/// on Ethiopian handwoven cloth.
///
/// Used sparingly and only as edging: section rules, the top of a summary
/// card, the journey path. The restraint is the point. Applied everywhere
/// it would read as costume rather than craft, so treat it as punctuation.
///
/// Drawn rather than imported so it scales to any width, recolours per
/// section, and costs nothing to ship.
class TibebBand extends StatelessWidget {
  final Color color;
  final double height;

  /// Width of one repeat. Smaller reads as finer weave.
  final double unit;

  const TibebBand({
    super.key,
    this.color = AppColors.leaf,
    this.height = 12,
    this.unit = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _TibebPainter(color: color, unit: unit)),
    );
  }
}

class _TibebPainter extends CustomPainter {
  final Color color;
  final double unit;

  _TibebPainter({required this.color, required this.unit});

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final midY = h / 2;

    // Two hairlines with a row of diamonds between them — the simplest
    // motif that still reads as woven rather than as a dotted rule.
    final line = Paint()
      ..color = color
      ..strokeWidth = h * 0.12
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, h * 0.06), Offset(size.width, h * 0.06), line);
    canvas.drawLine(Offset(0, h * 0.94), Offset(size.width, h * 0.94), line);

    final solid = Paint()..color = color;
    final open = Paint()
      ..color = color
      ..strokeWidth = h * 0.1
      ..style = PaintingStyle.stroke;

    final r = h * 0.3;
    var x = unit / 2;
    var filled = true;
    while (x < size.width + unit) {
      final diamond = Path()
        ..moveTo(x, midY - r)
        ..lineTo(x + r, midY)
        ..lineTo(x, midY + r)
        ..lineTo(x - r, midY)
        ..close();
      // Alternating solid/open diamonds give the band its rhythm.
      canvas.drawPath(diamond, filled ? solid : open);
      filled = !filled;
      x += unit;
    }
  }

  @override
  bool shouldRepaint(_TibebPainter old) =>
      old.color != color || old.unit != unit;
}
