import 'package:flutter/material.dart';

/// Lightweight page transition for the Windows UI.
/// Keeps the child subtree mounted, so IndexedStack pages retain their state.
class AnimatedTabBody extends StatefulWidget {
  final int index;
  final Widget child;

  const AnimatedTabBody({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  State<AnimatedTabBody> createState() => _AnimatedTabBodyState();
}

class _AnimatedTabBodyState extends State<AnimatedTabBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: 1,
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = Tween<double>(begin: 0.82, end: 1).animate(curve);
    _position = Tween<Offset>(
      begin: const Offset(0.012, 0),
      end: Offset.zero,
    ).animate(curve);
  }

  @override
  void didUpdateWidget(covariant AnimatedTabBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _position,
          child: widget.child,
        ),
      );
}
