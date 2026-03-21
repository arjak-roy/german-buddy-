import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/gemini_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'live_session_repository.g.dart';

class LiveSessionState {
  final bool isBuddyPreparing;
  final bool isBuddyLiveReady;
  final bool isBuddyVoiceActive;
  final bool isBuddyVoiceStopping;
  final String buddyVoiceTranscript;
  final int buddyInterruptToken;
  final String? buddyLiveError;
  final bool didStartLiveConversation;

  const LiveSessionState({
    this.isBuddyPreparing = false,
    this.isBuddyLiveReady = false,
    this.isBuddyVoiceActive = false,
    this.isBuddyVoiceStopping = false,
    this.buddyVoiceTranscript = '',
    this.buddyInterruptToken = 0,
    this.buddyLiveError,
    this.didStartLiveConversation = false,
  });

  LiveSessionState copyWith({
    bool? isBuddyPreparing,
    bool? isBuddyLiveReady,
    bool? isBuddyVoiceActive,
    bool? isBuddyVoiceStopping,
    String? buddyVoiceTranscript,
    int? buddyInterruptToken,
    String? buddyLiveError,
    bool? didStartLiveConversation,
  }) {
    return LiveSessionState(
      isBuddyPreparing: isBuddyPreparing ?? false,
      isBuddyLiveReady: isBuddyLiveReady ?? false,
      isBuddyVoiceActive: isBuddyVoiceActive ?? false,
      isBuddyVoiceStopping: isBuddyVoiceStopping ?? false,
      buddyVoiceTranscript: buddyVoiceTranscript ?? this.buddyVoiceTranscript,
      buddyInterruptToken: buddyInterruptToken ?? this.buddyInterruptToken,
      buddyLiveError: buddyLiveError,
      didStartLiveConversation: didStartLiveConversation ?? false,
    );
  }
}

@riverpod
class LiveSessionRepository extends _$LiveSessionRepository {
  StreamSubscription<void>? _buddyInterruptSub;

  @override
  LiveSessionState build() {
    final geminiService = GeminiService(); // Assuming it's a singleton or simple to instantiate
    _buddyInterruptSub = geminiService.buddyLiveInterruptedStream.listen((_) {
      state = state.copyWith(buddyInterruptToken: state.buddyInterruptToken + 1);
    });

    ref.onDispose(() {
      _buddyInterruptSub?.cancel();
    });

    return const LiveSessionState();
  }

  Future<void> prepareBuddyLiveSession({bool startConversation = false}) async {
    state = state.copyWith(
      isBuddyPreparing: false,
      isBuddyLiveReady: false,
      buddyLiveError: null,
    );
  }

  Future<void> startBuddyVoiceTurn() async {
    // Legacy mock
  }

  Future<void> stopBuddyVoiceTurn() async {
    state = state.copyWith(
      isBuddyVoiceActive: false,
      isBuddyVoiceStopping: false,
    );
  }

  Future<void> cancelBuddyVoiceTurn() async {
    state = state.copyWith(
      isBuddyVoiceActive: false,
    );
  }
}
