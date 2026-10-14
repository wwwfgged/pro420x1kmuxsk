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
