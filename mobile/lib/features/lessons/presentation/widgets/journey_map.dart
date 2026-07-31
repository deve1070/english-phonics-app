import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../phonics/domain/entities/lesson_entity.dart';
import '../../../home/presentation/widgets/level_style.dart';

/// The curriculum drawn as a path rather than listed as rows.
///
/// A ListView answers "what is available"; a child wants to know "where am
/// I, and what is next". A winding trail makes progress spatial — you can
/// see the ground you have covered behind you, which a scroll position
/// cannot express — and it turns eighteen rows of near-identical text into
/// something that reads as a board game.
///
/// The path is painted, not composed from images, so it recolours per
/// level and costs nothing to ship.
class JourneyMap extends StatelessWidget {
  final List<LessonEntity> lessons;
  final ValueChanged<LessonEntity> onTapLesson;

  const JourneyMap({
    super.key,
    required this.lessons,
    required this.onTapLesson,
  });

  /// How far a stop sits from the centre line, as a fraction of width.
  static const _swing = 0.26;
  static const _rowHeight = 128.0;

  /// A lesson opens when the one before it is finished.
  ///
  /// A lesson carrying no exercises can never be "finished", so it must not
  /// be allowed to block the trail — otherwise a gap in generated content
  /// walls off the rest of the curriculum. Treating empty lessons as
  /// passable keeps the path walkable while content is still being filled
  /// in.
  static List<bool> unlockedFlags(List<LessonEntity> lessons) {
    final flags = <bool>[];
    var open = true;
    for (final lesson in lessons) {
      flags.add(open);
      open = lesson.isCompleted || lesson.totalExercises == 0;
    }
    return flags;
  }

  @override
  Widget build(BuildContext context) {
    if (lessons.isEmpty) return const SizedBox.shrink();

    final unlocked = unlockedFlags(lessons);
    // The current stop is the first open-but-unfinished lesson: the one
    // thing on screen the child should be drawn to.
    final currentIndex = () {
      for (var i = 0; i < lessons.length; i++) {
        if (unlocked[i] && !lessons[i].isCompleted) return i;
      }
      return lessons.length - 1;
    }();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final centre = width / 2;
        final offsets = [
          for (var i = 0; i < lessons.length; i++)
            Offset(
              centre + (i.isEven ? -1 : 1) * width * _swing,
              _rowHeight / 2 + i * _rowHeight,
            ),
        ];

        return SizedBox(
          height: lessons.length * _rowHeight + AppSpacing.xl,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _TrailPainter(
                    points: offsets,
                    completedThrough: lessons.indexWhere((l) => !l.isCompleted),
                  ),
                ),
              ),
              for (var i = 0; i < lessons.length; i++)
                Positioned(
                  left: offsets[i].dx - AppSizes.journeyStop / 2,
                  top: offsets[i].dy - AppSizes.journeyStop / 2,
                  child: _Stop(
                    lesson: lessons[i],
                    index: i,
                    unlocked: unlocked[i],
                    isCurrent: i == currentIndex,
                    onTap: () => onTapLesson(lessons[i]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The trail itself: a dashed line threaded through the stops, solid where
/// the child has already been.
class _TrailPainter extends CustomPainter {
  final List<Offset> points;

  /// Index of the first unfinished lesson; everything before it is walked.
  final int completedThrough;

  _TrailPainter({required this.points, required this.completedThrough});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final walked = completedThrough < 0 ? points.length : completedThrough;

    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      // Curve the segment so the trail meanders instead of zig-zagging.
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, a.dy + (b.dy - a.dy) * 0.55, b.dx,
            b.dy - (b.dy - a.dy) * 0.55, b.dx, b.dy);

      // Segment i joins stop i to stop i+1. It counts as walked once the
      // child has *arrived* at i+1, which includes the stop they are
      // currently on — so the solid trail runs right up to where they are
      // standing rather than stopping one short of it.
      _drawTrail(canvas, path, i < walked);
    }
  }

  void _drawTrail(Canvas canvas, Path path, bool walked) {
    final paint = Paint()
      ..color = walked ? AppColors.leaf : AppColors.dormant
      ..style = PaintingStyle.stroke
      ..strokeWidth = walked ? 7 : 5
      ..strokeCap = StrokeCap.round;

    if (walked) {
      canvas.drawPath(path, paint);
      return;
    }

    // Dashes for ground not yet covered. Walked by metric so the spacing
    // stays even around the curve.
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = math.min(d + 11, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += 20;
      }
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.completedThrough != completedThrough || old.points != points;
}

class _Stop extends StatelessWidget {
  final LessonEntity lesson;
  final int index;
  final bool unlocked;
  final bool isCurrent;
  final VoidCallback onTap;

  const _Stop({
    required this.lesson,
    required this.index,
    required this.unlocked,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final levelColor = LevelStyle.color(lesson.level);
    final done = lesson.isCompleted;

    final fill = !unlocked
        ? AppColors.surfaceSunken
        : done
            ? levelColor
            : AppColors.surface;

    final stop = GestureDetector(
      onTap: unlocked ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: AppSizes.journeyStop,
        height: AppSizes.journeyStop,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(
            color: unlocked ? AppColors.border : AppColors.borderSoft,
            width: isCurrent ? AppBorders.heavy : AppBorders.standard,
          ),
          boxShadow: unlocked ? AppShadows.raised : AppShadows.flat,
        ),
        child: Center(child: _stopContent(done, levelColor)),
      ),
    );

    return Semantics(
      button: unlocked,
      label: unlocked
          ? 'Lesson ${lesson.order}, ${done ? 'complete' : 'not finished'}'
          : 'Lesson ${lesson.order}, locked',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The current stop breathes, so the eye lands on the one thing
          // the child is meant to do next.
          isCurrent
              ? stop
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.07, 1.07),
                    duration: 1100.ms,
                    curve: Curves.easeInOut,
                  )
              : stop,
        ],
      ),
    );
  }

  Widget _stopContent(bool done, Color levelColor) {
    if (!unlocked) {
      return const Icon(Icons.lock_rounded, size: 24, color: AppColors.dormant);
    }
    if (done) {
      return const Icon(Icons.check_rounded, size: 30, color: AppColors.onInk);
    }
    // Unfinished stops show the lesson's first letter rather than a number:
    // a child who cannot yet read digits reliably can still recognise the
    // sound they are heading towards.
    final symbol = lesson.phonemes.isNotEmpty
        ? lesson.phonemes.first.symbol.trim()
        : '${lesson.order}';
    return Padding(
      padding: const EdgeInsets.all(4),
      child: FittedBox(
        child: Text(
          symbol.isEmpty ? '${lesson.order}' : symbol,
          style: AppTextStyles.headingLarge.copyWith(color: levelColor),
        ),
      ),
    );
  }
}
