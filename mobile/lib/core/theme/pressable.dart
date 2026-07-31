import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';

/// A surface that physically depresses when touched.
///
/// The hard offset shadow in [AppShadows] describes a gap between the
/// surface and the page. Pressing closes that gap: the element slides down
/// by exactly the distance the shadow shrinks, so the two read as one
/// object being pushed rather than as a card plus a decoration.
///
/// This is the main reason the UI feels like objects instead of rectangles,
/// and it costs nothing — no blur, no elevation compositing, just a
/// translation and a shorter offset.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color? borderColor;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double borderWidth;

  /// Semantic description for screen readers. Worth setting: much of this
  /// UI is deliberately wordless.
  final String? semanticLabel;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.color = AppColors.surface,
    this.borderColor,
    this.radius = AppRadius.lg,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderWidth = AppBorders.standard,
    this.semanticLabel,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  bool get _enabled => widget.onTap != null;

  void _setDown(bool value) {
    if (!_enabled || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final depressed = _down && _enabled;

    return Semantics(
      button: _enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onTap: widget.onTap,
        // Opaque so the whole padded area is tappable, not just the child.
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(
            0,
            depressed ? AppShadows.pressTravel : 0,
            0,
          ),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _enabled ? widget.color : AppColors.surfaceSunken,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: _enabled
                  ? (widget.borderColor ?? AppColors.border)
                  : AppColors.borderSoft,
              width: widget.borderWidth,
            ),
            boxShadow: !_enabled
                ? AppShadows.flat
                : depressed
                    ? AppShadows.pressed
                    : AppShadows.raised,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Non-interactive counterpart to [Pressable] — same visual language, no
/// press behaviour. For cards that display rather than invite.
class PaperCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color? borderColor;
  final double radius;
  final EdgeInsetsGeometry padding;
  final List<BoxShadow> shadow;

  const PaperCard({
    super.key,
    required this.child,
    this.color = AppColors.surface,
    this.borderColor,
    this.radius = AppRadius.lg,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.shadow = AppShadows.card,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? AppColors.border,
          width: AppBorders.standard,
        ),
        boxShadow: shadow,
      ),
      child: child,
    );
  }
}
