import 'dart:typed_data';

class BuddyDialogResponse {
  final String text;
  final Uint8List? audioBytes;
  final String? audioMimeType;
  final String? inputTranscription;
  final String? outputTranscription;

  const BuddyDialogResponse({
    required this.text,
    this.audioBytes,
    this.audioMimeType,
    this.inputTranscription,
    this.outputTranscription,
  });
}
