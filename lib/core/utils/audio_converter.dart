import 'dart:typed_data';

class AudioConverter {
  static Uint8List wrapPcm16LeToWav(Uint8List pcmData, {int sampleRate = 24000}) {
    const channels = 1;
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = pcmData.length;
    final totalSize = 44 + dataSize;

    final out = BytesBuilder(copy: false);
    void wAscii(String s) => out.add(Uint8List.fromList(s.codeUnits));
    void w16(int v) => out.add(Uint8List.fromList([v & 0xFF, (v >> 8) & 0xFF]));
    void w32(int v) => out.add(
      Uint8List.fromList([
        v & 0xFF,
        (v >> 8) & 0xFF,
        (v >> 16) & 0xFF,
        (v >> 24) & 0xFF,
      ]),
    );

    wAscii('RIFF');
    w32(totalSize - 8);
    wAscii('WAVE');
    wAscii('fmt ');
    w32(16);
    w16(1);
    w16(channels);
    w32(sampleRate);
    w32(byteRate);
    w16(blockAlign);
    w16(bitsPerSample);
    wAscii('data');
    w32(dataSize);
    out.add(pcmData);

    return out.takeBytes();
  }
}
