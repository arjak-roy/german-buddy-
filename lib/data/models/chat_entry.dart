/// Simple model representing a single chat entry in the Buddy conversation.
class ChatEntry {
  final String text;
  final String? translated;
  final bool isUser;

  ChatEntry({required this.text, this.translated, this.isUser = false});
}
