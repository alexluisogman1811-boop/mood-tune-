import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../application/preview_audio.dart';

/// Play/pause control with progress for a provider-supplied preview clip.
/// Audio stops when the widget leaves the screen.
class PreviewPlayer extends ConsumerStatefulWidget {
  const PreviewPlayer({required this.url, this.onOpenExternally, super.key});

  final Uri url;

  /// Offered as a fallback when in-app playback fails.
  final VoidCallback? onOpenExternally;

  @override
  ConsumerState<PreviewPlayer> createState() => _PreviewPlayerState();
}

class _PreviewPlayerState extends ConsumerState<PreviewPlayer> {
  late final PreviewAudio _audio = ref.read(previewAudioFactoryProvider)();
  final _subs = <StreamSubscription<Object?>>[];
  PreviewPhase _phase = PreviewPhase.idle;
  Duration _position = Duration.zero;
  bool _loaded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _subs
      ..add(_audio.phases.listen((p) => setState(() => _phase = p)))
      ..add(_audio.position.listen((d) => setState(() => _position = d)));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _audio.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_phase == PreviewPhase.playing) {
      await _audio.pause();
      return;
    }
    if (!_loaded) {
      setState(() => _phase = PreviewPhase.loading);
      try {
        await _audio.load(widget.url);
        _loaded = true;
      } on Object {
        // Network, codec or platform errors: offer the external fallback.
        if (mounted) {
          setState(() {
            _failed = true;
            _phase = PreviewPhase.idle;
          });
        }
        return;
      }
    }
    if (_phase == PreviewPhase.completed) await _audio.seekToStart();
    _audio.play();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_failed) {
      return Row(
        children: [
          const Icon(Icons.error_outline),
          const SizedBox(width: 12),
          const Expanded(child: Text('The preview could not be played.')),
          if (widget.onOpenExternally case final open?)
            TextButton(onPressed: open, child: const Text('Open')),
        ],
      );
    }

    final total = _audio.duration;
    final progress = total == null || total == Duration.zero
        ? 0.0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final playing = _phase == PreviewPhase.playing;
    final loading = _phase == PreviewPhase.loading;

    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: playing ? 'Pause preview' : 'Play preview',
          onPressed: loading ? null : _toggle,
          icon: loading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(playing ? Icons.pause : Icons.play_arrow),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Preview', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Semantics(
                label: 'Preview progress ${(progress * 100).round()} percent',
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
