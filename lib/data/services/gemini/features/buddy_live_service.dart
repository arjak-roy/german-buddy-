import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../core/gemini_ai_client.dart';
import '../core/gemini_models.dart';
import '../models/buddy_dialog_response.dart';
import '../prompts/system_prompts.dart';
import 'conversation_service.dart';

class GeminiBuddyLiveService {
  GeminiBuddyLiveService({
    GeminiAiClient? aiClient,
    GeminiConversationService? conversationService,
  }) : _aiClient = aiClient ?? GeminiAiClient(),
       _conversation = conversationService ?? GeminiConversationService();

  final GeminiAiClient _aiClient;
  final GeminiConversationService _conversation;

  LiveSession? _buddyLiveSession;
  Future<void>? _buddyLiveMediaStreamFuture;
  bool _buddyLiveTurnInProgress = false;
  bool _buddyLiveReady = false;
  String? _buddyLiveLastError;
  int _buddyLiveSentAudioBytes = 0;
  int _buddyLiveSentAudioPackets = 0;
  int _buddyLiveDroppedSilentPackets = 0;
  bool _buddyLiveLoggedFirstChunk = false;
  final StreamController<void> _buddyLiveInterruptedController =
      StreamController<void>.broadcast();

  Stream<void> get buddyLiveInterruptedStream =>
      _buddyLiveInterruptedController.stream;
  bool get isBuddyLiveConnected => _buddyLiveSession != null && _buddyLiveReady;
  String? get buddyLiveLastError => _buddyLiveLastError;

  Future<void> startBuddyLiveSession([String? systemPrompt]) async {
    if (isBuddyLiveConnected) return;

    await closeBuddyLiveSession();

    final prompt = (systemPrompt != null && systemPrompt.isNotEmpty)
        ? systemPrompt
        : GeminiSystemPrompts.buddy;

    final liveModel = _aiClient.ai.liveGenerativeModel(
      model: GeminiModels.buddyLiveModel,
      systemInstruction: Content.system(prompt),
      liveGenerationConfig: LiveGenerationConfig(
        responseModalities: const [ResponseModalities.audio],
        temperature: 0.2,
        maxOutputTokens: 500,
      ),
    );

    try {
      _buddyLiveSession = await liveModel.connect();
      if (_buddyLiveSession != null) {
        debugPrint('[BuddyLive] session connected successfully.');
      }
      _buddyLiveLastError = null;
      _buddyLiveReady = true;
    } catch (e) {
      _buddyLiveLastError = 'Buddy live connect failed: $e';
      _buddyLiveSession = null;
      _buddyLiveReady = false;
      rethrow;
    }
  }

  Future<void> closeBuddyLiveSession() async {
    await _buddyLiveMediaStreamFuture?.catchError((_) {});
    _buddyLiveMediaStreamFuture = null;

    _buddyLiveReady = false;
    _buddyLiveTurnInProgress = false;

    await _buddyLiveSession?.close();
    _buddyLiveSession = null;
  }

  Future<BuddyDialogResponse> askBuddyLive(
    String userMessage, [
    String? systemPrompt,
  ]) async {
    try {
      await startBuddyLiveSession(systemPrompt);

      final session = _buddyLiveSession;
      if (session == null || !_buddyLiveReady) {
        return _conversation.askBuddy(userMessage, systemPrompt);
      }

      if (_buddyLiveTurnInProgress) {
        return _conversation.askBuddy(userMessage, systemPrompt);
      }

      _buddyLiveTurnInProgress = true;
      try {
        await session.sendTextRealtime(userMessage);
        await session.send(turnComplete: true);
        return await _collectBuddyLiveTurnResponse(session).timeout(
          const Duration(seconds: 35),
          onTimeout: () {
            _buddyLiveLastError = 'Buddy live text turn timed out.';
            return const BuddyDialogResponse(
              text: 'Unexpected response format',
            );
          },
        );
      } finally {
        _buddyLiveTurnInProgress = false;
      }
    } catch (e) {
      _buddyLiveLastError = 'Buddy live text turn failed: $e';
      await closeBuddyLiveSession();
      return _conversation.askBuddy(userMessage, systemPrompt);
    }
  }

  Future<void> startBuddyLiveAudioTurn(
    Stream<Uint8List> audioStream, {
    int sampleRateHz = 16000,
    String? systemPrompt,
  }) async {
    await startBuddyLiveSession(systemPrompt);

    final session = _buddyLiveSession;
    if (session == null || !_buddyLiveReady) {
      throw StateError('Buddy live session is not ready.');
    }
    if (_buddyLiveTurnInProgress) {
      throw StateError('Buddy live turn already in progress.');
    }

    _buddyLiveTurnInProgress = true;
    _buddyLiveSentAudioBytes = 0;
    _buddyLiveSentAudioPackets = 0;
    _buddyLiveDroppedSilentPackets = 0;
    _buddyLiveLoggedFirstChunk = false;
    debugPrint(
      '[BuddyLive] start audio turn sampleRateHz=$sampleRateHz ready=$_buddyLiveReady',
    );

    final mediaChunkStream = _toMediaChunkStream(
      audioStream,
      sampleRateHz: sampleRateHz,
    );
    _buddyLiveMediaStreamFuture =
        _startMediaStreamCompat(session, mediaChunkStream)..catchError((error) {
          _buddyLiveLastError =
              'Buddy live audio stream send failed (sampleRateHz=$sampleRateHz): $error';
          _buddyLiveReady = false;
          debugPrint('[BuddyLive] $_buddyLiveLastError');
        });
  }

  Future<BuddyDialogResponse> finishBuddyLiveAudioTurn() async {
    final session = _buddyLiveSession;
    if (!_buddyLiveTurnInProgress || session == null) {
      _buddyLiveLastError =
          'Buddy live audio turn finished without an active session.';
      return const BuddyDialogResponse(text: '');
    }

    try {
      await _buddyLiveMediaStreamFuture?.catchError((_) {});
      _buddyLiveMediaStreamFuture = null;

      await session.send(turnComplete: true);
      var reply = await _collectBuddyLiveTurnResponse(session).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          _buddyLiveLastError = 'Buddy live audio turn timed out.';
          return const BuddyDialogResponse(text: '');
        },
      );

      final isEmptyTurn =
          reply.text.trim().isEmpty &&
          (reply.audioBytes == null || reply.audioBytes!.isEmpty) &&
          (reply.inputTranscription ?? '').trim().isEmpty &&
          (reply.outputTranscription ?? '').trim().isEmpty;
      if (isEmptyTurn && _buddyLiveSentAudioBytes > 0) {
        debugPrint(
          '[BuddyLive] empty audio turn; sending one-shot text nudge fallback.',
        );
        await session.sendTextRealtime(
          'Please reply now with one short German sentence and one short English translation.',
        );
        await session.send(turnComplete: true);
        final nudgedReply = await _collectBuddyLiveTurnResponse(session).timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            _buddyLiveLastError =
                'Buddy live nudge fallback timed out after empty audio turn.';
            return const BuddyDialogResponse(text: '');
          },
        );

        final nudgedHasContent =
            nudgedReply.text.trim().isNotEmpty ||
            (nudgedReply.audioBytes != null &&
                nudgedReply.audioBytes!.isNotEmpty) ||
            (nudgedReply.outputTranscription ?? '').trim().isNotEmpty;
        if (nudgedHasContent) {
          _buddyLiveLastError = null;
          reply = nudgedReply;
        }
      } else if (isEmptyTurn && _buddyLiveSentAudioBytes == 0) {
        _buddyLiveLastError =
            'No microphone audio bytes were sent during the live turn.';
      }

      debugPrint(
        '[BuddyLive] finish audio turn '
        'sentPackets=$_buddyLiveSentAudioPackets '
        'sentBytes=$_buddyLiveSentAudioBytes '
        'textLen=${reply.text.length} '
        'audioBytes=${reply.audioBytes?.length ?? 0} '
        'inputTxLen=${reply.inputTranscription?.length ?? 0} '
        'outputTxLen=${reply.outputTranscription?.length ?? 0} '
        'lastError=${_buddyLiveLastError ?? 'none'}',
      );
      return reply;
    } catch (e) {
      _buddyLiveLastError = 'Buddy live audio turn failed: $e';
      debugPrint('[BuddyLive] $_buddyLiveLastError');
      await closeBuddyLiveSession();
      rethrow;
    } finally {
      _buddyLiveTurnInProgress = false;
    }
  }

  Future<void> cancelBuddyLiveAudioTurn() async {
    await _buddyLiveMediaStreamFuture?.catchError((_) {});
    _buddyLiveMediaStreamFuture = null;
    _buddyLiveTurnInProgress = false;
  }

  Stream<InlineDataPart> _toMediaChunkStream(
    Stream<Uint8List> audioStream, {
    required int sampleRateHz,
  }) async* {
    var isFirstChunk = true;
    await for (final chunk in audioStream) {
      if (chunk.isEmpty) continue;

      final prepared = _prepareLivePcmChunk(
        chunk,
        sampleRateHz: sampleRateHz,
        isFirstChunk: isFirstChunk,
      );
      isFirstChunk = false;
      if (prepared == null || prepared.isEmpty) continue;

      // Some Android devices emit zeroed startup frames. Dropping a short
      // warm-up window avoids sending invalid/empty-looking audio first.
      if (_buddyLiveSentAudioPackets == 0 &&
          _buddyLiveDroppedSilentPackets < 12 &&
          _isNearSilencePcm16(prepared)) {
        _buddyLiveDroppedSilentPackets += 1;
        if (_buddyLiveDroppedSilentPackets == 1 ||
            _buddyLiveDroppedSilentPackets == 12) {
          debugPrint(
            '[BuddyLive] dropping silent startup chunk '
            'count=$_buddyLiveDroppedSilentPackets len=${prepared.length}',
          );
        }
        continue;
      }

      _buddyLiveSentAudioPackets += 1;
      _buddyLiveSentAudioBytes += prepared.length;
      yield InlineDataPart('audio/pcm', prepared);
    }
  }

  bool _isNearSilencePcm16(Uint8List bytes) {
    if (bytes.length < 2) return true;

    var maxAbs = 0;
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      var sample = (bytes[i] & 0xFF) | (bytes[i + 1] << 8);
      if ((sample & 0x8000) != 0) {
        sample = sample - 0x10000;
      }
      final absVal = sample < 0 ? -sample : sample;
      if (absVal > maxAbs) maxAbs = absVal;
      if (maxAbs > 24) return false;
    }
    return true;
  }

  Future<void> _startMediaStreamCompat(
    LiveSession session,
    Stream<InlineDataPart> mediaChunkStream,
  ) async {
    await for (final chunk in mediaChunkStream) {
      await session.sendAudioRealtime(chunk);
    }
  }

  Future<void> disposeBuddyLive() async {
    await cancelBuddyLiveAudioTurn();
    await closeBuddyLiveSession();
    await _buddyLiveInterruptedController.close();
  }

  Future<BuddyDialogResponse> _collectBuddyLiveTurnResponse(
    LiveSession session,
  ) async {
    final audioBuilder = BytesBuilder(copy: false);
    final textBuffer = StringBuffer();
    final inputTranscriptionBuffer = StringBuffer();
    final outputTranscriptionBuffer = StringBuffer();

    await for (final response in session.receive()) {
      final message = response.message;

      if (message is GoingAwayNotice) {
        _buddyLiveLastError =
            'Buddy live session is ending soon (timeLeft: ${message.timeLeft ?? 'n/a'}).';
      }

      if (message is! LiveServerContent) continue;

      if (message.interrupted == true) {
        _buddyLiveInterruptedController.add(null);
      }

      final inputText = (message.inputTranscription?.text ?? '').trim();
      if (inputText.isNotEmpty) {
        inputTranscriptionBuffer.write(inputText);
      }

      final outputText = (message.outputTranscription?.text ?? '').trim();
      if (outputText.isNotEmpty) {
        outputTranscriptionBuffer.write(outputText);
      }

      final modelTurn = message.modelTurn;
      if (modelTurn == null) continue;

      for (final part in modelTurn.parts) {
        if (part is TextPart && part.text.trim().isNotEmpty) {
          textBuffer.write(part.text);
          continue;
        }

        if (part is InlineDataPart && part.mimeType.startsWith('audio/')) {
          if (part.bytes.isNotEmpty) {
            audioBuilder.add(part.bytes);
          }
        }
      }
    }

    final audioBytes = audioBuilder.takeBytes();
    final inputTranscription = inputTranscriptionBuffer.toString().trim();
    final outputTranscription = outputTranscriptionBuffer.toString().trim();
    final text = textBuffer.toString().trim();
    final hasAudio = audioBytes.isNotEmpty;

    String resolvedText = '';
    if (text.isNotEmpty) {
      resolvedText = text;
    } else if (outputTranscription.isNotEmpty) {
      resolvedText = outputTranscription;
    } else if (!hasAudio) {
      _buddyLiveLastError =
          _buddyLiveLastError ?? 'Buddy live returned an empty turn.';
    }

    debugPrint(
      '[BuddyLive] collected response '
      'textLen=${text.length} '
      'audioBytes=${audioBytes.length} '
      'inputTxLen=${inputTranscription.length} '
      'outputTxLen=${outputTranscription.length}',
    );

    return BuddyDialogResponse(
      text: resolvedText,
      audioBytes: audioBytes.isEmpty ? null : audioBytes,
      audioMimeType: audioBytes.isEmpty ? null : 'audio/pcm',
      inputTranscription: inputTranscription.isEmpty
          ? null
          : inputTranscription,
      outputTranscription: outputTranscription.isEmpty
          ? null
          : outputTranscription,
    );
  }

  Uint8List? _prepareLivePcmChunk(
    Uint8List raw, {
    required int sampleRateHz,
    required bool isFirstChunk,
  }) {
    if (!_buddyLiveLoggedFirstChunk) {
      _buddyLiveLoggedFirstChunk = true;
      final preview = _hexPreview(raw, maxBytes: 16);
      final looksWav = _looksLikeWav(raw);
      final looksUnsupported = _looksLikeUnsupportedAudioContainer(raw);
      debugPrint(
        '[BuddyLive] first chunk rawLen=${raw.length} '
        'sampleRateHz=$sampleRateHz '
        'looksWav=$looksWav '
        'looksUnsupportedContainer=$looksUnsupported '
        'headHex=$preview',
      );
    }

    var bytes = raw;

    if (isFirstChunk && _looksLikeWav(bytes)) {
      if (bytes.length <= 44) return null;
      bytes = Uint8List.sublistView(bytes, 44);
    }

    if (_looksLikeUnsupportedAudioContainer(bytes)) {
      _buddyLiveLastError =
          'Buddy live audio stream appears encoded/containerized, but Gemini Live expects raw PCM16. sampleRateHz=$sampleRateHz';
      return null;
    }

    if (bytes.length.isOdd) {
      if (bytes.length <= 1) return null;
      bytes = Uint8List.sublistView(bytes, 0, bytes.length - 1);
    }

    return bytes;
  }

  bool _looksLikeWav(Uint8List bytes) {
    if (bytes.length < 12) return false;
    return bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x41 &&
        bytes[10] == 0x56 &&
        bytes[11] == 0x45;
  }

  bool _looksLikeUnsupportedAudioContainer(Uint8List bytes) {
    if (bytes.length < 4) return false;

    final isOgg =
        bytes[0] == 0x4F &&
        bytes[1] == 0x67 &&
        bytes[2] == 0x67 &&
        bytes[3] == 0x53;
    if (isOgg) return true;

    if (bytes.length >= 2) {
      final isAdts = bytes[0] == 0xFF && (bytes[1] & 0xF0) == 0xF0;
      if (isAdts) return true;
    }

    return false;
  }

  String _hexPreview(Uint8List bytes, {int maxBytes = 16}) {
    if (bytes.isEmpty) return '';
    final take = bytes.length < maxBytes ? bytes.length : maxBytes;
    final sb = StringBuffer();
    for (var i = 0; i < take; i++) {
      if (i > 0) sb.write(' ');
      sb.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
