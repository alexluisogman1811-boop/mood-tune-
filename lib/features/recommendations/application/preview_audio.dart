import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

enum PreviewPhase { idle, loading, playing, paused, completed }

/// Minimal audio surface for 30-second previews, so widgets can be tested
/// without a real audio engine.
abstract interface class PreviewAudio {
  Stream<PreviewPhase> get phases;
  Stream<Duration> get position;
  Duration? get duration;

  /// Prepares [url] (HTTPS only). Throws if it cannot be loaded.
  Future<void> load(Uri url);

  /// Starts playback and returns immediately.
  void play();
  Future<void> pause();
  Future<void> seekToStart();
  Future<void> dispose();
}

/// Creates a fresh player per preview widget; overridden in tests.
final previewAudioFactoryProvider = Provider<PreviewAudio Function()>(
  (ref) => JustAudioPreview.new,
);

class JustAudioPreview implements PreviewAudio {
  final _player = AudioPlayer();

  @override
  Stream<PreviewPhase> get phases => _player.playerStateStream.map((s) {
    return switch (s.processingState) {
      ProcessingState.idle => PreviewPhase.idle,
      ProcessingState.loading ||
      ProcessingState.buffering => PreviewPhase.loading,
      ProcessingState.completed => PreviewPhase.completed,
      ProcessingState.ready =>
        s.playing ? PreviewPhase.playing : PreviewPhase.paused,
    };
  });

  @override
  Stream<Duration> get position => _player.positionStream;

  @override
  Duration? get duration => _player.duration;

  @override
  Future<void> load(Uri url) async {
    if (url.scheme != 'https') {
      throw ArgumentError.value(url, 'url', 'Previews must use HTTPS');
    }
    await _player.setUrl(url.toString());
  }

  // just_audio's play() completes only when playback stops, so don't wait.
  @override
  void play() => unawaited(_player.play());

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seekToStart() => _player.seek(Duration.zero);

  @override
  Future<void> dispose() => _player.dispose();
}
