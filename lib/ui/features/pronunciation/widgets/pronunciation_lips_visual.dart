import 'package:flutter/material.dart';

import '../utils/phoneme_mapping.dart';
export '../utils/phoneme_mapping.dart' show PronunciationViseme;

PronunciationViseme visemeForSegment(String segment) {
  return classifyVisemeForSegment(segment);
}

class PronunciationAnimatedLips extends StatelessWidget {
  final bool isPlaying;
  final int activeIndex;
  final List<PronunciationViseme> visemes;
  final double width;
  final double height;

  const PronunciationAnimatedLips({
    super.key,
    required this.isPlaying,
    required this.activeIndex,
    required this.visemes,
    this.width = 176,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    final safeIndex = activeIndex.clamp(0, visemes.isEmpty ? 0 : visemes.length - 1);
    final viseme = (!isPlaying || visemes.isEmpty || activeIndex < 0)
        ? PronunciationViseme.neutral
        : visemes[safeIndex];

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutQuad,
      tween: Tween<double>(begin: 1.0, end: isPlaying ? 1.04 : 1.0),
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutQuad,
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFDA4AF)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFB7185).withAlpha(isPlaying ? 56 : 36),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 24,
              top: 44,
              child: _CheekGlow(active: isPlaying),
            ),
            Positioned(
              right: 24,
              top: 44,
              child: _CheekGlow(active: isPlaying),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _LipsPainter(viseme: viseme, isPlaying: isPlaying),
              ),
            ),
            const Positioned(
              right: 10,
              top: 8,
              child: Icon(
                Icons.record_voice_over_rounded,
                size: 14,
                color: Color(0xFFE11D48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheekGlow extends StatelessWidget {
  final bool active;

  const _CheekGlow({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: active ? 22 : 18,
      height: active ? 14 : 12,
      decoration: BoxDecoration(
        color: const Color(0xFFFB7185).withAlpha(active ? 40 : 25),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _LipsPainter extends CustomPainter {
  final PronunciationViseme viseme;
  final bool isPlaying;

  const _LipsPainter({required this.viseme, required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    final pose = _poseForViseme(viseme);
    final center = Offset(size.width / 2, size.height / 2 + 10);
    final lipWidth = size.width * pose.widthFactor;
    final opening = size.height * pose.openFactor;
    final cornerLift = size.height * pose.cornerLift;

    final leftCorner = Offset(center.dx - (lipWidth / 2), center.dy + cornerLift);
    final rightCorner = Offset(center.dx + (lipWidth / 2), center.dy + cornerLift);
    final topPeak = Offset(center.dx, center.dy - opening - (size.height * 0.07));
    final bottomDip = Offset(center.dx, center.dy + opening + (size.height * 0.06));

    final upperLip = Path()
      ..moveTo(leftCorner.dx, leftCorner.dy)
      ..quadraticBezierTo(
        center.dx - (lipWidth * 0.23),
        topPeak.dy,
        center.dx,
        center.dy - (opening * 0.52),
      )
      ..quadraticBezierTo(
        center.dx + (lipWidth * 0.23),
        topPeak.dy,
        rightCorner.dx,
        rightCorner.dy,
      )
      ..quadraticBezierTo(
        center.dx + (lipWidth * 0.24),
        center.dy - (opening * 0.25),
        center.dx,
        center.dy - (opening * 0.12),
      )
      ..quadraticBezierTo(
        center.dx - (lipWidth * 0.24),
        center.dy - (opening * 0.25),
        leftCorner.dx,
        leftCorner.dy,
      )
      ..close();

    final lowerLip = Path()
      ..moveTo(leftCorner.dx, leftCorner.dy)
      ..quadraticBezierTo(
        center.dx - (lipWidth * 0.30),
        bottomDip.dy,
        center.dx,
        center.dy + (opening * 0.46),
      )
      ..quadraticBezierTo(
        center.dx + (lipWidth * 0.30),
        bottomDip.dy,
        rightCorner.dx,
        rightCorner.dy,
      )
      ..quadraticBezierTo(
        center.dx + (lipWidth * 0.20),
        center.dy + (opening * 0.05),
        center.dx,
        center.dy + (opening * 0.02),
      )
      ..quadraticBezierTo(
        center.dx - (lipWidth * 0.20),
        center.dy + (opening * 0.05),
        leftCorner.dx,
        leftCorner.dy,
      )
      ..close();

    final lipOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFF9F1239).withAlpha(isPlaying ? 224 : 184)
      ..strokeCap = StrokeCap.round;

    final upperFill = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFFB7185).withAlpha(isPlaying ? 242 : 199),
          const Color(0xFFE11D48).withAlpha(isPlaying ? 235 : 189),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCenter(center: center, width: lipWidth, height: size.height * 0.24));

    final lowerFill = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFFB7185).withAlpha(isPlaying ? 224 : 184),
          const Color(0xFFBE123C).withAlpha(isPlaying ? 219 : 173),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCenter(center: center, width: lipWidth, height: size.height * 0.28));

    canvas.drawPath(lowerLip, lowerFill);
    canvas.drawPath(upperLip, upperFill);
    canvas.drawPath(lowerLip, lipOutline);
    canvas.drawPath(upperLip, lipOutline);

    final mouthRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + (opening * 0.06)),
      width: lipWidth * pose.innerWidth,
      height: (opening * 1.32).clamp(4.0, size.height * 0.42),
    );

    final mouthCavity = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF1E1B4B).withAlpha(isPlaying ? 209 : 158);
    canvas.drawRRect(
      RRect.fromRectAndRadius(mouthRect, Radius.circular(mouthRect.height)),
      mouthCavity,
    );

    if (mouthRect.height > 10) {
      final teethRect = Rect.fromLTWH(
        mouthRect.left + 3,
        mouthRect.top + 2,
        mouthRect.width - 6,
        (mouthRect.height * 0.28).clamp(2.5, 6.0),
      );
      final teethPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFFF7ED).withAlpha(230);
      canvas.drawRRect(
        RRect.fromRectAndRadius(teethRect, const Radius.circular(999)),
        teethPaint,
      );

      final tongueRect = Rect.fromCenter(
        center: Offset(mouthRect.center.dx, mouthRect.bottom - (mouthRect.height * 0.24)),
        width: mouthRect.width * 0.58,
        height: mouthRect.height * 0.32,
      );
      final tonguePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFB7185).withAlpha(112);
      canvas.drawRRect(
        RRect.fromRectAndRadius(tongueRect, Radius.circular(tongueRect.height)),
        tonguePaint,
      );
    }

    final gloss = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withAlpha(isPlaying ? 66 : 46);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - (lipWidth * 0.17), center.dy - (opening * 0.58)),
        width: lipWidth * 0.24,
        height: 6,
      ),
      gloss,
    );
  }

  @override
  bool shouldRepaint(covariant _LipsPainter oldDelegate) {
    return oldDelegate.viseme != viseme || oldDelegate.isPlaying != isPlaying;
  }
}

class _LipPose {
  final double widthFactor;
  final double openFactor;
  final double cornerLift;
  final double innerWidth;

  const _LipPose({
    required this.widthFactor,
    required this.openFactor,
    required this.cornerLift,
    required this.innerWidth,
  });
}

_LipPose _poseForViseme(PronunciationViseme viseme) {
  switch (viseme) {
    case PronunciationViseme.openA:
      return const _LipPose(widthFactor: 0.38, openFactor: 0.19, cornerLift: 0.0, innerWidth: 0.78);
    case PronunciationViseme.rounded:
      return const _LipPose(widthFactor: 0.24, openFactor: 0.20, cornerLift: -0.01, innerWidth: 0.76);
    case PronunciationViseme.spread:
      return const _LipPose(widthFactor: 0.46, openFactor: 0.09, cornerLift: -0.015, innerWidth: 0.84);
    case PronunciationViseme.consonant:
      return const _LipPose(widthFactor: 0.34, openFactor: 0.10, cornerLift: -0.004, innerWidth: 0.8);
    case PronunciationViseme.tight:
      return const _LipPose(widthFactor: 0.30, openFactor: 0.07, cornerLift: 0.0, innerWidth: 0.75);
    case PronunciationViseme.neutral:
      return const _LipPose(widthFactor: 0.35, openFactor: 0.095, cornerLift: 0.0, innerWidth: 0.8);
  }
}
