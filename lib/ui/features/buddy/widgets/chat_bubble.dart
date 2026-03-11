import 'package:flutter/material.dart';

class ChatMessage extends StatelessWidget {
  final String text;
  final String? translated;
  final bool isUser;

  const ChatMessage({
    required this.text,
    this.translated,
    this.isUser = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // choose a light background for buddy; white on white makes bubble
    // invisible. also add a slight drop shadow for separation.
    final bubbleColor = isUser ? Colors.blue : Colors.grey.shade100;
    final textColor = isUser ? Colors.white : Colors.black87;
    final translateColor = isUser ? Colors.white70 : Colors.blueGrey;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isUser ? 16 : 0),
      bottomRight: Radius.circular(isUser ? 0 : 16),
    );

    final bubble = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            text,
            style: TextStyle(color: textColor),
          ),
        ),
        if (translated != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 6.0),
            child: Text(
              translated!,
              style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: translateColor),
            ),
          ),
      ],
    );

    // avatar placeholder circles
    final avatar = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isUser ? Colors.brown[200] : Colors.black,
        shape: BoxShape.circle,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isUser
            ? [
                Expanded(child: const SizedBox()),
                Flexible(child: bubble),
                const SizedBox(width: 8),
                avatar,
              ]
            : [
                avatar,
                const SizedBox(width: 8),
                Flexible(child: bubble),
                Expanded(child: const SizedBox()),
              ],
      ),
    );
  }
}
