import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

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

  bool _containsMarkdownTable(String value) {
    final lines = value.split('\n');
    final tableSeparator = RegExp(
      r'^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$',
      multiLine: false,
    );

    for (var i = 0; i < lines.length - 1; i++) {
      final header = lines[i].trim();
      final separator = lines[i + 1].trim();
      if (header.contains('|') && tableSeparator.hasMatch(separator)) {
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final defaultBubbleMaxWidth =
        screenWidth < 420 ? screenWidth * 0.82 : screenWidth * 0.74;

    // choose a light background for buddy; white on white makes bubble
    // invisible. also add a slight drop shadow for separation.
    final bubbleColor = isUser ? Colors.blue : Colors.grey.shade100;
    final textColor = isUser ? Colors.white : Colors.black87;
    final translateColor = isUser ? Colors.white70 : Colors.blueGrey;
    final aiHasTable = !isUser && _containsMarkdownTable(text);
    final bubbleMaxWidth = aiHasTable
        ? screenWidth - 56  // 32 avatar + 8 gap + 8 outer padding each side
        : defaultBubbleMaxWidth;
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
          constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isUser
              ? Text(
                  text,
                  style: TextStyle(color: textColor),
                  softWrap: true,
                )
              : (aiHasTable
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: IntrinsicWidth(
                        child: MarkdownBody(
                          data: text,
                          extensionSet: md.ExtensionSet.gitHubFlavored,
                          softLineBreak: true,
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                            p: TextStyle(color: textColor),
                            strong:
                                TextStyle(color: textColor, fontWeight: FontWeight.w700),
                            em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
                            code: TextStyle(
                              color: textColor,
                              backgroundColor: Colors.black.withValues(alpha: 0.06),
                              fontFamily: 'monospace',
                            ),
                            blockquote:
                                TextStyle(color: textColor.withValues(alpha: 0.85)),
                            tableBorder: TableBorder.all(
                              color: Colors.black.withValues(alpha: 0.12),
                            ),
                            tableCellsPadding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            tableHead:
                                TextStyle(color: textColor, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    )
                  : MarkdownBody(
                      data: text,
                      extensionSet: md.ExtensionSet.gitHubFlavored,
                      softLineBreak: true,
                      styleSheet:
                          MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                        p: TextStyle(color: textColor),
                        strong: TextStyle(color: textColor, fontWeight: FontWeight.w700),
                        em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
                        code: TextStyle(
                          color: textColor,
                          backgroundColor: Colors.black.withValues(alpha: 0.06),
                          fontFamily: 'monospace',
                        ),
                        blockquote:
                            TextStyle(color: textColor.withValues(alpha: 0.85)),
                        tableBorder: TableBorder.all(
                          color: Colors.black.withValues(alpha: 0.12),
                        ),
                        tableCellsPadding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        tableHead:
                            TextStyle(color: textColor, fontWeight: FontWeight.w700),
                      ),
                    )),
        ),
        if (translated != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 6.0),
            child: Text(
              translated!,
              softWrap: true,
              style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: translateColor),
            ),
          ),
        if (aiHasTable)
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: null, // TODO: implement WhatsApp share
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Send to WhatsApp'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF25D366),
                  textStyle: const TextStyle(fontSize: 13),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ),
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
                if (aiHasTable) Expanded(child: bubble)
                else ...[
                  Flexible(child: bubble),
                  Expanded(child: const SizedBox()),
                ],
              ],
      ),
    );
  }
}
