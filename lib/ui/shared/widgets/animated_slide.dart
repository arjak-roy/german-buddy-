import 'package:flutter/material.dart';

class AnimatedSlide extends StatefulWidget {
  final Widget child;
  final int order;
  final bool fromLeft;

  const AnimatedSlide({
    super.key,
    required this.child,
    required this.order,
    this.fromLeft = true,
  });

  @override
  State<AnimatedSlide> createState() => _AnimatedSlideState();
}

class _AnimatedSlideState extends State<AnimatedSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    final delay = Duration(milliseconds: 100 * widget.order);
    Future.delayed(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });

    final xOffset = widget.fromLeft ? -0.5 : 0.5;
    _animation = Tween<Offset>(
      begin: Offset(xOffset, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: _animation,
        child: widget.child,
      ),
    );
  }
}
