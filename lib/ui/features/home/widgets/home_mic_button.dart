import 'package:flutter/material.dart';

import 'mic_button.dart';

/// Widget used on the home screen as the microphone launcher.  Keeping it
/// separate from the buddy button allows future styling or behavior
/// differences without affecting the conversation page.
class HomeMicButton extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const HomeMicButton({this.onTap, this.onLongPress, super.key});

  @override
  Widget build(BuildContext context) {
    return MicButton(
      heroTag: 'micHero',
      onTap: onTap,
      onLongPress: onLongPress,
      showLabels: true,
    );
  }
}
