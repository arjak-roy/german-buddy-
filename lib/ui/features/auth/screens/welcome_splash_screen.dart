import 'package:flutter/material.dart';

class WelcomeSplashScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const WelcomeSplashScreen({
    super.key,
    required this.onFinished,
  });

  @override
  State<WelcomeSplashScreen> createState() => _WelcomeSplashScreenState();
}

class _WelcomeSplashScreenState extends State<WelcomeSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _writeController;
  late final AnimationController _cursorController;
  late final Animation<double> _writeProgress;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();

    _writeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward();

    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..repeat(reverse: true);

    _fadeIn = CurvedAnimation(
      parent: _writeController,
      curve: const Interval(0, 0.35, curve: Curves.easeOut),
    );

    _writeProgress = CurvedAnimation(
      parent: _writeController,
      curve: Curves.easeInOutCubic,
    );

    Future<void>.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      widget.onFinished();
    });
  }

  @override
  void dispose() {
    _writeController.dispose();
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const helloStyle = TextStyle(
      color: Color(0xFF1D1B45),
      fontSize: 86,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.italic,
      fontFamily: 'cursive',
      letterSpacing: 0.4,
      height: 1,
    );

    final painter = TextPainter(
      text: const TextSpan(text: 'Hello', style: helloStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final textWidth = painter.width;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8F9FF), Color(0xFFEDEFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeIn,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _writeController,
                    _cursorController,
                  ]),
                  builder: (context, _) {
                    final progress = _writeProgress.value;
                    final cursorX = textWidth * progress;

                    return SizedBox(
                      width: textWidth + 20,
                      height: 110,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          ClipRect(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: const Text(
                                'Hello',
                                style: helloStyle,
                              ),
                            ),
                          ),
                          Positioned(
                            left: cursorX,
                            top: 22,
                            child: Opacity(
                              opacity: _cursorController.value,
                              child: Container(
                                width: 3,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2B266A),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    color: Color(0xFF5C5B7A),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
