import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moodscape/app/router.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/mood/application/mood_controller.dart';
import 'package:moodscape/features/mood/domain/mood.dart';
import 'package:moodscape/features/preferences/application/preferences_controller.dart';
import 'package:moodscape/features/preferences/domain/music_preferences.dart';
import 'package:moodscape/features/recommendations/application/disliked_tracks.dart';
import 'package:moodscape/features/recommendations/application/recommendations_controller.dart';
import 'package:moodscape/features/recommendations/data/track_source.dart';
import 'package:moodscape/features/recommendations/domain/match_scorer.dart';
import 'package:moodscape/features/recommendations/domain/track.dart';
import 'package:moodscape/features/recommendations/presentation/results_screen.dart';
import 'package:moodscape/features/recommendations/presentation/track_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Source implements TrackSource {
  @override
  String get label => 'Test';
  @override
  bool get isDemo => true;
  @override
  String? get notice => null;
  @override
  Future<List<Track>> candidates(MatchContext ctx) async => [
    for (var i = 0; i < 4; i++)
      Track(
        id: 't$i',
        title: 'Song $i',
        artist: 'A',
        provider: MusicProvider.demo,
        valence: 65,
        energy: 25 + i * 10,
      ),
  ];
}

Future<ProviderContainer> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      trackSourceProvider.overrideWithValue(_Source()),
    ],
  );
  addTearDown(c.dispose);
  c.read(moodControllerProvider.notifier).toggle(Mood.calm);
  await c
      .read(musicPreferencesProvider.notifier)
      .save(const MusicPreferences(playlistLength: 10)); // all 4 shown
  final router = GoRouter(
    initialLocation: AppRoutes.results,
    routes: [
      GoRoute(
        path: AppRoutes.results,
        builder: (_, _) => const ResultsScreen(),
        routes: [
          GoRoute(
            path: 'track/:id',
            builder: (_, s) =>
                TrackDetailScreen(trackId: s.pathParameters['id']!),
          ),
        ],
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
  return c;
}

void main() {
  testWidgets('"Not for me" removes the card, says so, and Undo restores it', (
    tester,
  ) async {
    final c = await _pump(tester);
    // Catalogue of 4 with a playlist length of 10: all 4 shown.
    expect(find.text('Song 0'), findsOneWidget);

    await tester.tap(find.byTooltip('Not for me').first);
    await tester.pumpAndSettle();

    expect(find.text('Song 0'), findsNothing);
    expect(c.read(dislikedTracksProvider), {'t0'});
    expect(find.textContaining('Removed “Song 0”'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Song 0'), findsOneWidget);
    expect(c.read(dislikedTracksProvider), isEmpty);
  });

  testWidgets('says so when no other song is left to suggest', (tester) async {
    // All 4 catalogue songs are already shown, so nothing can replace one.
    await _pump(tester);

    await tester.tap(find.byTooltip('Not for me').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('No other songs left'), findsOneWidget);
  });

  testWidgets('"Not for me" on the details screen goes back and removes it', (
    tester,
  ) async {
    final c = await _pump(tester);

    await tester.tap(find.text('Song 1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Not for me — suggest another'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Not for me — suggest another'));
    await tester.pumpAndSettle();

    expect(find.text('Song 1'), findsNothing);
    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(c.read(dislikedTracksProvider), {'t1'});
  });
}
