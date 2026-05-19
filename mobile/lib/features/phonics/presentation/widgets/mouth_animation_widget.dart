import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';

// ── Viseme data ────────────────────────────────────────────────────
class _VisemeEvent {
  final int visemeId;
  final double offsetMs;
  const _VisemeEvent({required this.visemeId, required this.offsetMs});
}

class _MouthShape {
  final double jawOpen;
  final double lipWidth;
  final double lipRound;
  final bool teethVisible;
  final bool tongueUp;

  const _MouthShape({
    required this.jawOpen,
    required this.lipWidth,
    required this.lipRound,
    this.teethVisible = false,
    this.tongueUp = false,
  });
}

const Map<int, _MouthShape> _visemeShapes = {
  0: _MouthShape(jawOpen: 0.0, lipWidth: 0.5, lipRound: 0.0),
  1: _MouthShape(
      jawOpen: 0.85, lipWidth: 0.9, lipRound: 0.0, teethVisible: true),
  2: _MouthShape(
      jawOpen: 1.0, lipWidth: 0.8, lipRound: 0.0, teethVisible: true),
  3: _MouthShape(jawOpen: 0.8, lipWidth: 0.4, lipRound: 0.6),
  4: _MouthShape(
      jawOpen: 0.6, lipWidth: 0.8, lipRound: 0.0, teethVisible: true),
  5: _MouthShape(jawOpen: 0.55, lipWidth: 0.6, lipRound: 0.2),
  6: _MouthShape(
      jawOpen: 0.3, lipWidth: 1.0, lipRound: 0.0, teethVisible: true),
  7: _MouthShape(jawOpen: 0.2, lipWidth: 0.2, lipRound: 0.9),
  8: _MouthShape(jawOpen: 0.5, lipWidth: 0.3, lipRound: 0.8),
  9: _MouthShape(jawOpen: 0.7, lipWidth: 0.5, lipRound: 0.4),
  10: _MouthShape(jawOpen: 0.6, lipWidth: 0.6, lipRound: 0.3),
  11: _MouthShape(
      jawOpen: 0.75, lipWidth: 0.7, lipRound: 0.0, teethVisible: true),
  12: _MouthShape(jawOpen: 0.5, lipWidth: 0.6, lipRound: 0.0),
  13: _MouthShape(jawOpen: 0.35, lipWidth: 0.3, lipRound: 0.7),
  14: _MouthShape(jawOpen: 0.4, lipWidth: 0.7, lipRound: 0.0, tongueUp: true),
  15: _MouthShape(
      jawOpen: 0.15, lipWidth: 0.8, lipRound: 0.0, teethVisible: true),
  16: _MouthShape(jawOpen: 0.25, lipWidth: 0.3, lipRound: 0.6),
  17: _MouthShape(jawOpen: 0.2, lipWidth: 0.7, lipRound: 0.0, tongueUp: true),
  18: _MouthShape(
      jawOpen: 0.1, lipWidth: 0.7, lipRound: 0.0, teethVisible: true),
  19: _MouthShape(jawOpen: 0.2, lipWidth: 0.6, lipRound: 0.0, tongueUp: true),
  20: _MouthShape(jawOpen: 0.4, lipWidth: 0.5, lipRound: 0.0),
  21: _MouthShape(jawOpen: 0.0, lipWidth: 0.6, lipRound: 0.0),
};

const Map<String, int> _ipaToViseme = {
  'æ': 1,
  'ə': 1,
  'ʌ': 1,
  'ɑ': 2,
  'ɔ': 3,
  'ɛ': 4,
  'e': 4,
  'eɪ': 4,
  'ɜ': 5,
  'ɪ': 6,
  'i': 6,
  'iː': 6,
  'ʊ': 7,
  'u': 7,
  'uː': 7,
  'oʊ': 8,
  'o': 8,
  'aʊ': 9,
  'ɔɪ': 10,
  'aɪ': 11,
  'h': 12,
  'r': 13,
  'l': 14,
  's': 15,
  'z': 15,
  'ʃ': 16,
  'ʒ': 16,
  'ð': 17,
  'θ': 17,
  'f': 18,
  'v': 18,
  'd': 19,
  't': 19,
  'n': 19,
  'k': 20,
  'g': 20,
  'ŋ': 20,
  'p': 21,
  'b': 21,
  'm': 21,
};

_MouthShape _shapeForViseme(int id) => _visemeShapes[id] ?? _visemeShapes[0]!;
int _visemeForIPA(String ipa) => _ipaToViseme[ipa] ?? 0;
double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

_MouthShape _lerpShape(_MouthShape a, _MouthShape b, double t) => _MouthShape(
      jawOpen: _lerpDouble(a.jawOpen, b.jawOpen, t),
      lipWidth: _lerpDouble(a.lipWidth, b.lipWidth, t),
      lipRound: _lerpDouble(a.lipRound, b.lipRound, t),
      teethVisible: t > 0.5 ? b.teethVisible : a.teethVisible,
      tongueUp: t > 0.5 ? b.tongueUp : a.tongueUp,
    );

// ── Widget ─────────────────────────────────────────────────────────
/// Mouth animation widget.
///
/// FIX: No longer requires a tap to animate.
/// Call [triggerAnimation] from outside (e.g. from the lesson screen
/// right after playPhonemeAudio) to fetch visemes and animate.
/// Falls back to a static IPA-based mouth shape when backend unavailable.
class MouthAnimationWidget extends StatefulWidget {
  final String phonemeType;
  final String phonemeSymbol;
  final Color color;

  /// Called by parent to trigger animation alongside audio playback.
  /// The parent should call this at the same time as playing audio.
  final Stream<void>? playTrigger;

  const MouthAnimationWidget({
    super.key,
    required this.phonemeType,
    required this.phonemeSymbol,
    required this.color,
    this.playTrigger,
  });

  @override
  State<MouthAnimationWidget> createState() => MouthAnimationWidgetState();
}

class MouthAnimationWidgetState extends State<MouthAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _shapeController;
  late Animation<double> _shapeAnim;

  _MouthShape _currentShape = _visemeShapes[0]!;
  _MouthShape _targetShape = _visemeShapes[0]!;
  bool _isAnimating = false;

  late Dio _dio;

  @override
  void initState() {
    super.initState();
    _dio = getIt<Dio>();
    _shapeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _shapeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shapeController, curve: Curves.easeInOut),
    );

    _setStaticShape(widget.phonemeSymbol);
  }

  @override
  void didUpdateWidget(MouthAnimationWidget old) {
    super.didUpdateWidget(old);
    if (old.phonemeSymbol != widget.phonemeSymbol) {
      _setStaticShape(widget.phonemeSymbol);
    }
  }

  void _setStaticShape(String symbol) {
    final visemeId = _visemeForIPA(symbol);
    _currentShape = _shapeForViseme(visemeId);
    _targetShape = _currentShape;
    if (mounted) setState(() {});
  }

  /// Called by the parent screen right when audio starts playing.
  /// Fetches the viseme sequence and animates in sync.
  Future<void> triggerAnimation() async {
    if (_isAnimating) return;
    setState(() => _isAnimating = true);

    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/tts/phoneme-with-visemes',
        data: {'text': widget.phonemeSymbol},
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );

      final data = response.data as Map<String, dynamic>;
      final visemeList = data['visemes'] as List<dynamic>;
      final visemes = visemeList
          .map((v) => _VisemeEvent(
                visemeId: (v['viseme_id'] as num).toInt(),
                offsetMs: (v['offset_ms'] as num).toDouble(),
              ))
          .toList();

      await _animateVisemes(visemes);
    } catch (_) {
      // Fallback: simple open-close animation using IPA
      await _playStaticAnimation();
    } finally {
      if (mounted) {
        _animateTo(_visemeShapes[0]!);
        setState(() => _isAnimating = false);
      }
    }
  }

  Future<void> _animateVisemes(List<_VisemeEvent> visemes) async {
    if (visemes.isEmpty) {
      await _playStaticAnimation();
      return;
    }
    final start = DateTime.now();
    for (final event in visemes) {
      if (!mounted || !_isAnimating) break;
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      final wait = event.offsetMs - elapsed;
      if (wait > 0) await Future.delayed(Duration(milliseconds: wait.toInt()));
      if (!mounted) break;
      _animateTo(_shapeForViseme(event.visemeId));
    }
  }

  Future<void> _playStaticAnimation() async {
    // Open and close 3 times to show the target mouth shape
    final target = _shapeForViseme(_visemeForIPA(widget.phonemeSymbol));
    for (int i = 0; i < 3; i++) {
      if (!mounted) break;
      _animateTo(target);
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) break;
      _animateTo(_visemeShapes[0]!);
      await Future.delayed(const Duration(milliseconds: 250));
    }
  }

  void _animateTo(_MouthShape target) {
    if (!mounted) return;
    _currentShape = _lerpShape(_currentShape, _targetShape, _shapeAnim.value);
    _targetShape = target;
    _shapeController.forward(from: 0.0);
  }

  _MouthShape get _displayShape => _shapeController.isAnimating
      ? _lerpShape(_currentShape, _targetShape, _shapeAnim.value)
      : _targetShape;

  @override
  void dispose() {
    _shapeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomPaint(
                size: const Size(120, 80),
                painter: _MouthPainter(
                  shape: _displayShape,
                  color: widget.color,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _isAnimating ? 'Watch carefully!' : 'Mouth position guide',
                style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
              ),
            ],
          ),
          // Badge
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 3),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isAnimating)
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation(widget.color),
                      ),
                    )
                  else
                    Icon(Icons.face_rounded, color: widget.color, size: 12),
                  const SizedBox(width: 3),
                  Text('Mouth Guide',
                      style: AppTextStyles.label
                          .copyWith(color: widget.color, fontSize: 10)),
                ],
              ),
            ),
          ),
          // IPA hint
          Positioned(
            bottom: AppSpacing.sm,
            left: AppSpacing.md,
            child: Text(
              '/${widget.phonemeSymbol}/',
              style: AppTextStyles.label
                  .copyWith(color: widget.color, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mouth painter ──────────────────────────────────────────────────
class _MouthPainter extends CustomPainter {
  final _MouthShape shape;
  final Color color;

  _MouthPainter({required this.shape, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final adjustedW = size.width *
        (0.6 + (1 - shape.lipRound) * shape.lipWidth * 0.2) *
        (1.0 - shape.lipRound * 0.3);
    final mouthH = size.height * shape.jawOpen;

    final border = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final fill = Paint()..style = PaintingStyle.fill;

    if (shape.jawOpen < 0.05) {
      // Closed mouth
      canvas.drawPath(
        Path()
          ..moveTo(cx - adjustedW / 2, cy)
          ..quadraticBezierTo(
              cx, cy + 6 * (1 - shape.lipRound), cx + adjustedW / 2, cy),
        border,
      );
      canvas.drawPath(
        Path()
          ..moveTo(cx - adjustedW / 2, cy)
          ..quadraticBezierTo(cx, cy - 8, cx + adjustedW / 2, cy),
        border..color = color.withOpacity(0.5),
      );
    } else {
      // Open mouth — cavity
      fill.color = const Color(0xFF3A1A0A);
      canvas.drawPath(
        Path()
          ..moveTo(cx - adjustedW / 2, cy)
          ..quadraticBezierTo(cx, cy - mouthH * 0.7, cx + adjustedW / 2, cy)
          ..quadraticBezierTo(cx, cy + mouthH * 0.7, cx - adjustedW / 2, cy)
          ..close(),
        fill,
      );
      // Teeth
      if (shape.teethVisible && shape.jawOpen > 0.2) {
        fill.color = Colors.white.withOpacity(0.92);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx, cy - mouthH * 0.15),
              width: adjustedW * 0.7,
              height: mouthH * 0.3,
            ),
            const Radius.circular(3),
          ),
          fill,
        );
      }
      // Tongue
      if (shape.tongueUp && shape.jawOpen > 0.15) {
        fill.color = const Color(0xFFE8706A).withOpacity(0.9);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, cy + mouthH * 0.1),
            width: adjustedW * 0.5,
            height: mouthH * 0.35,
          ),
          fill,
        );
      }
      // Lips
      canvas.drawPath(
        Path()
          ..moveTo(cx - adjustedW / 2, cy)
          ..quadraticBezierTo(
              cx * 0.6, cy - mouthH * 0.5, cx, cy - mouthH * 0.65)
          ..quadraticBezierTo(
              cx * 1.4, cy - mouthH * 0.5, cx + adjustedW / 2, cy),
        border..color = color,
      );
      canvas.drawPath(
        Path()
          ..moveTo(cx - adjustedW / 2, cy)
          ..quadraticBezierTo(cx, cy + mouthH * 0.8, cx + adjustedW / 2, cy),
        border..color = color.withOpacity(0.85),
      );
      // Corners
      final corner = Paint()
        ..color = color.withOpacity(0.6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx - adjustedW / 2, cy), 3, corner);
      canvas.drawCircle(Offset(cx + adjustedW / 2, cy), 3, corner);
    }
  }

  @override
  bool shouldRepaint(_MouthPainter old) =>
      old.shape.jawOpen != shape.jawOpen ||
      old.shape.lipWidth != shape.lipWidth ||
      old.shape.lipRound != shape.lipRound ||
      old.shape.teethVisible != shape.teethVisible ||
      old.shape.tongueUp != shape.tongueUp;
}
