import 'package:flutter/material.dart';

import '../../home/widgets/mic_button.dart';

/// Separate wrapper for the mic button when used inside the buddy screen.
/// This keeps the home and buddy buttons decoupled for styling/behavior
/// changes later.
class BuddyMicButton extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;
  final bool isRecording;
  final double voiceLevel;
  const BuddyMicButton({
    this.onTap,
    this.onLongPress,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.isRecording = false,
    this.voiceLevel = 0.0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MicButton(
      heroTag: 'micHero',
      onTap: onTap,
      onLongPress: onLongPress,
      onLongPressStart: onLongPressStart,
      onLongPressEnd: onLongPressEnd,
      isRecording: isRecording,
      voiceLevel: voiceLevel,
      showLabels: false,
      diameter: 74,
      iconSize: 30,
    );
  }
}
