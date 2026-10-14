import 'package:flutter/material.dart';

/// Lightweight entrance/exit animation for persistent app tabs.
///
/// The child remains mounted so tab state (scroll position, selections and
/// text fields) is preserved. Only the active tab receives pointer input.
class AnimatedTabVisibility extends StatelessWidget {
  final bool active;
  final Widget child;
  final Duration duration;

  const AnimatedTabVisibility({
    super.key,
    required this.active,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !active,
      child: ExcludeSemantics(
        excluding: !active,
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: duration,
          curve: Curves.easeOutCubic,
          child: AnimatedSlide(
            offset: active ? Offset.zero : const Offset(0.018, 0),
            duration: duration,
            curve: Curves.easeOutCubic,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A small, reusable press feedback animation for custom cards and controls.
class AnimatedPressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Duration duration;

  const AnimatedPressScale({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.duration = const Duration(milliseconds: 110),
  });

  @override
  State<AnimatedPressScale> createState() => _AnimatedPressScaleState();
}

class _AnimatedPressScaleState extends State<AnimatedPressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
