import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moodscape/features/recommendations/application/preview_audio.dart';
import 'package:moodscape/features/recommendations/presentation/preview_player.dart';

class _FakeAudio implements PreviewAudio {
  _FakeAudio({this.failLoad = false});

  final bool failLoad;
  final _phases = StreamController<PreviewPhase>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final calls = <String>[];
  bool disposed = false;
  Completer<void>? loadGate;

  void emit(PreviewPhase p) => _phases.add(p);
  void at(Duration d) => _position.add(d);

  @override
  Stream<PreviewPhase> get phases => _phases.stream;

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Duration? get duration => const Duration(seconds: 30);

  @override
  Future<void> load(Uri url) async {
    calls.add('load $url');
    await loadGate?.future;
    if (failLoad) throw Exception('codec');
  }

  @override
  void play() {
    calls.add('play');
    emit(PreviewPhase.playing);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    emit(PreviewPhase.paused);
  }

  @override
  Future<void> seekToStart() async => calls.add('seek0');

  @override
  Future<void> dispose() async {
    disposed = true;
    await _phases.close();
    await _position.close();
  }
}

final _url = Uri.parse('https://audio-ssl.itunes.apple.com/p.m4a');

Future<void> _pump(
  WidgetTester tester,
  _FakeAudio audio, {
  VoidCallback? onOpen,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [previewAudioFactoryProvider.overrideWithValue(() => audio)],
      child: MaterialApp(
        home: Scaffold(
          body: PreviewPlayer(url: _url, onOpenExternally: onOpen),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('loads once, then plays and pauses', (tester) async {
    final audio = _FakeAudio();
    await _pump(tester, audio);

    await tester.tap(find.byTooltip('Play preview'));
    await tester.pump();
    expect(audio.calls, ['load $_url', 'play']);
    expect(find.byTooltip('Pause preview'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause preview'));
    await tester.pump();
    await tester.tap(find.byTooltip('Play preview'));
    await tester.pump();

    expect(audio.calls, ['load $_url', 'play', 'pause', 'play']);
  });

  testWidgets('shows a spinner while loading', (tester) async {
    final audio = _FakeAudio()..loadGate = Completer<void>();
    await _pump(tester, audio);

    await tester.tap(find.byTooltip('Play preview'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    audio.loadGate!.complete();
    await tester.pump();
    expect(find.byTooltip('Pause preview'), findsOneWidget);
  });

  testWidgets('progress follows the playback position', (tester) async {
    final audio = _FakeAudio();
    await _pump(tester, audio);
    await tester.tap(find.byTooltip('Play preview'));
    await tester.pump();

    audio.at(const Duration(seconds: 15));
    await tester.pump();

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.5, 0.001));
  });

  testWidgets('replays from the start after the clip ends', (tester) async {
    final audio = _FakeAudio();
    await _pump(tester, audio);
    await tester.tap(find.byTooltip('Play preview'));
    await tester.pump();

    audio.emit(PreviewPhase.completed);
    await tester.pump();
    await tester.tap(find.byTooltip('Play preview'));
    await tester.pump();

    expect(audio.calls, ['load $_url', 'play', 'seek0', 'play']);
  });

  testWidgets('a failed load offers opening the preview elsewhere', (
    tester,
  ) async {
    var opened = false;
    final audio = _FakeAudio(failLoad: true);
    await _pump(tester, audio, onOpen: () => opened = true);

    await tester.tap(find.byTooltip('Play preview'));
    await tester.pump();

    expect(find.text('The preview could not be played.'), findsOneWidget);
    await tester.tap(find.text('Open'));
    expect(opened, isTrue);
  });

  testWidgets('audio is released when the player leaves the screen', (
    tester,
  ) async {
    final audio = _FakeAudio();
    await _pump(tester, audio);

    await tester.pumpWidget(const SizedBox());

    expect(audio.disposed, isTrue);
  });
}
