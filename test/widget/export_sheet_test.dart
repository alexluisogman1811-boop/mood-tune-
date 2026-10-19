import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moodscape/app/router.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/mood/application/mood_controller.dart';
import 'package:moodscape/features/mood/domain/mood.dart';
import 'package:moodscape/features/recommendations/application/recommendations_controller.dart';
import 'package:moodscape/features/recommendations/data/track_links.dart';
import 'package:moodscape/features/recommendations/data/track_source.dart';
import 'package:moodscape/features/recommendations/domain/match_scorer.dart';
import 'package:moodscape/features/recommendations/domain/track.dart';
import 'package:moodscape/features/recommendations/presentation/results_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Source implements TrackSource {
  @override
  String get label => 'Test';
  @override
  bool get isDemo => true;
  @override
  String? get notice => null;
  @override
  Future<List<Track>> candidates(MatchContext ctx) async => const [
    Track(
      id: 'a',
      title: 'So What',
      artist: 'Miles Davis',
      provider: MusicProvider.demo,
      valence: 65,
      energy: 25,
    ),
    Track(
      id: 'b',
      title: 'Take Five',
      artist: 'Dave Brubeck',
      provider: MusicProvider.demo,
      valence: 60,
      energy: 40,
    ),
  ];
}

void main() {
  testWidgets('export copies "Artist - Title" lines and opens the tool', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    final opened = <Uri>[];
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        trackSourceProvider.overrideWithValue(_Source()),
        urlOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
    );
    addTearDown(c.dispose);
    c.read(moodControllerProvider.notifier).toggle(Mood.calm);
    final router = GoRouter(
      initialLocation: AppRoutes.results,
      routes: [
        GoRoute(
          path: AppRoutes.results,
          builder: (_, _) => const ResultsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // No Spotify connection → the export option is offered.
    await tester.tap(find.text('Make this a Spotify playlist'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy song list'));
    await tester.pumpAndSettle();
    expect(copied, 'Miles Davis - So What\nDave Brubeck - Take Five');
    expect(find.text('Copied 2 songs.'), findsOneWidget);

    await tester.tap(find.text('Open TuneMyMusic'));
    await tester.pump();
    expect(opened.single.host, 'www.tunemymusic.com');
  });
}
