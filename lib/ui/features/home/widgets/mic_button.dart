import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';

/// A circular microphone button used both on the home page and the
/// buddy conversation page. [heroTag] allows a smooth transition between
/// the two screens, and [onTap] can be provided for navigation.
class MicButton extends StatefulWidget {
  final String heroTag;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;
  final VoidCallback? onLongPressCancel;
  final bool showLabels;
  final double diameter;
  final double iconSize;
  final bool isRecording;
  final double voiceLevel;

  const MicButton({
    this.heroTag = 'micHero',
    this.onTap,
    this.onLongPress,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.onLongPressCancel,
    this.showLabels = true,
    this.diameter = 120,
    this.iconSize = 48,
    this.isRecording = false,
    this.voiceLevel = 0.0,
    super.key,
  });

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _coreScale;
  late final Animation<double> _ringScale;
  late final Animation<double> _ringFade;
  late final Animation<double> _sweepRotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _coreScale = Tween<double>(begin: 0.98, end: 1.07).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuad),
    );
    _ringScale = Tween<double>(
      begin: 0.80,
      end: 1.50,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad));
    _ringFade = Tween<double>(
      begin: 0.40,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInQuad));
    _sweepRotation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.isRecording ? widget.voiceLevel.clamp(0.0, 1.0) : 0.0;
    final wave = (math.sin(_controller.value * math.pi * 32) + 1) * 0.5;
    final jitter = widget.isRecording ? wave * (0.06 + (level * 0.14)) : 0.0;
    final reactiveLevel = (level + jitter).clamp(0.0, 1.0);
    final ringSize = widget.diameter * 1.54;
    final glowOpacity = widget.isRecording
        ? 0.58 + (reactiveLevel * 0.42)
        : 0.4;
    final borderWidth = widget.isRecording ? 2.6 + (reactiveLevel * 3.6) : 2.0;
    final recordingBoost = widget.isRecording
        ? 1.0 + (reactiveLevel * 0.16)
        : 1.0;
    final pulseBoost = widget.isRecording
        ? (1.0 + (reactiveLevel * 0.35))
        : 1.0;

    final mic = Hero(
      tag: widget.heroTag,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onLongPressStart: (_) => widget.onLongPressStart?.call(),
        onLongPressEnd: (_) => widget.onLongPressEnd?.call(),
        onLongPressCancel: () => widget.onLongPressCancel?.call(),
        child: SizedBox(
          width: ringSize,
          height: ringSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (_, __) {
                  return Opacity(
                    opacity: _ringFade.value * pulseBoost,
                    child: Transform.scale(
                      scale: _ringScale.value + (reactiveLevel * 0.28),
                      child: Container(
                        width: widget.diameter,
                        height: widget.diameter,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color.fromARGB(255, 43, 118, 248),
                            width: borderWidth,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (_, __) {
                  return Transform.rotate(
                    angle: _sweepRotation.value * 6.28318530718,
                    child: Container(
                      width: ringSize,
                      height: ringSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            Colors.blueAccent.withOpacity(0.0),
                            Colors.blueAccent.withOpacity(
                              widget.isRecording
                                  ? 0.30 + (reactiveLevel * 0.46)
                                  : 0.22,
                            ),
                            Colors.blueAccent.withOpacity(0.0),
                          ],
                          stops: const [0.0, 0.2, 0.42],
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Glassmorphic effect for the core mic button
              ScaleTransition(
                scale: _coreScale,
                child: Transform.scale(
                  scale: recordingBoost,
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        width: widget.diameter,
                        height: widget.diameter,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color.fromARGB(
                                255,
                                30,
                                30,
                                243,
                              ).withOpacity(0.28),
                              const Color.fromARGB(
                                255,
                                8,
                                105,
                                185,
                              ).withOpacity(0.18),
                              Colors.blueAccent.withOpacity(0.22),
                            ],
                            stops: const [0.2, 0.7, 1.0],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.32),
                            width: 1.6,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(glowOpacity),
                              blurRadius: widget.isRecording
                                  ? 34 + (reactiveLevel * 26)
                                  : 24,
                              spreadRadius: widget.isRecording
                                  ? 5 + (reactiveLevel * 10)
                                  : 2,
                            ),
                            BoxShadow(
                              color: const Color.fromARGB(
                                255,
                                8,
                                105,
                                185,
                              ).withOpacity(0.18 + (reactiveLevel * 0.18)),
                              blurRadius: widget.isRecording
                                  ? 36 + (reactiveLevel * 22)
                                  : 30,
                              spreadRadius: widget.isRecording
                                  ? 8 + (reactiveLevel * 10)
                                  : 6,
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          reverseDuration: const Duration(milliseconds: 120),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: Tween<double>(begin: 0.8, end: 1.0)
                                  .animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutBack,
                                    ),
                                  ),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: Icon(
                            widget.isRecording ? Icons.graphic_eq : Icons.mic,
                            key: ValueKey<bool>(widget.isRecording),
                            size: widget.iconSize,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      children: [
        mic,
        if (widget.showLabels) ...[
          const SizedBox(height: 16),
          const Text(
            'Speak to Buddy',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap and hold to speak to Buddy',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
