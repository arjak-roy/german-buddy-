import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with TickerProviderStateMixin {
  late final List<_Circle> _circles;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _circles = List.generate(5, (_) => _Circle(vsync: this));
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => setState(() {
        for (final circle in _circles) {
          circle.respawn();
        }
      }),
    );
  }

  @override
  void dispose() {
    for (final circle in _circles) {
      circle.dispose();
    }
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AnimatedBackgroundPainter(
        circles: _circles.map((c) => c.value).toList(),
      ),
      child: Container(),
    );
  }
}

class _Circle {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late double _x;
  late double _y;
  late double _radius;
  late double _opacity;

  _Circle({required TickerProvider vsync}) {
    _controller = AnimationController(
      vsync: vsync,
      duration: Duration(milliseconds: 2000 + math.Random().nextInt(2000)),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
    respawn();
    _controller.forward();
  }

  void respawn() {
    _x = math.Random().nextDouble();
    _y = math.Random().nextDouble();
    _radius = 0.1 + math.Random().nextDouble() * 0.2;
    _opacity = 0.1 + math.Random().nextDouble() * 0.2;
    _controller.duration = Duration(
      milliseconds: 2000 + math.Random().nextInt(2000),
    );
    _controller
      ..reset()
      ..forward();
  }

  _CircleValue get value => _CircleValue(
    animation: _animation.value,
    x: _x,
    y: _y,
    radius: _radius,
    opacity: _opacity,
  );

  void dispose() {
    _controller.dispose();
  }
}

@immutable
class _CircleValue {
  final double animation;
  final double x;
  final double y;
  final double radius;
  final double opacity;

  const _CircleValue({
    required this.animation,
    required this.x,
    required this.y,
    required this.radius,
    required this.opacity,
  });
}

class _AnimatedBackgroundPainter extends CustomPainter {
  final List<_CircleValue> circles;

  _AnimatedBackgroundPainter({required this.circles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final circle in circles) {
      final radius = circle.radius * size.width * circle.animation;
      paint.color = Color.fromRGBO(
        255,
        255,
        255,
        circle.opacity * (1 - circle.animation),
      );
      canvas.drawCircle(
        Offset(circle.x * size.width, circle.y * size.height),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AnimatedBackgroundPainter oldDelegate) {
    return true;
  }
}
