import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moodscape/app/router.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/mood/application/mood_controller.dart';
import 'package:moodscape/features/mood/domain/mood.dart';
import 'package:moodscape/features/preferences/domain/music_preferences.dart';
import 'package:moodscape/features/recommendations/application/recommendations_controller.dart';
import 'package:moodscape/features/recommendations/data/track_links.dart';
import 'package:moodscape/features/recommendations/data/track_source.dart';
import 'package:moodscape/features/recommendations/domain/match_scorer.dart';
import 'package:moodscape/features/recommendations/domain/track.dart';
import 'package:moodscape/features/recommendations/presentation/results_screen.dart';
import 'package:moodscape/features/recommendations/presentation/track_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSource implements TrackSource {
  _FakeSource(this.tracks);
  final List<Track> tracks;

  @override
  String get label => 'Fake catalogue';

  @override
  bool get isDemo => true;

  @override
  String? get notice => null;

  @override
  Future<List<Track>> candidates(MatchContext ctx) async => tracks;
}

Track _t(
  String id, {
  required int valence,
  required int energy,
  Set<Genre> genres = const {Genre.jazz},
}) => Track(
  id: id,
  title: 'Song $id',
  artist: 'Artist $id',
  album: 'Album $id',
  provider: MusicProvider.demo,
  valence: valence,
  energy: energy,
  genres: genres,
  language: MusicLanguage.english,
  isInstrumental: false,
);

final _tracks = [
  _t('calm', valence: 65, energy: 25),
  _t('loud', valence: 80, energy: 90, genres: {Genre.rock}),
  _t('mid', valence: 50, energy: 50),
];

Future<(ProviderContainer, List<Uri>)> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'music_preferences.v1': '{"playlistLength": 10}',
  });
  final sp = await SharedPreferences.getInstance();
  final opened = <Uri>[];
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      trackSourceProvider.overrideWithValue(_FakeSource(_tracks)),
      currentYearProvider.overrideWithValue(2026),
      urlOpenerProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return true;
      }),
    ],
  );
  addTearDown(container.dispose);
  container.read(moodControllerProvider.notifier).toggle(Mood.calm);

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
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (container, opened);
}

void main() {
  testWidgets('lists ranked songs with scores, demo notice and disclaimer', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);

    expect(find.text('Demo mode'), findsOneWidget);
    expect(find.textContaining('not a scientific measure'), findsOneWidget);
    final titles = tester
        .widgetList<Text>(find.textContaining('Song '))
        .map((t) => t.data)
        .toList();
    expect(titles.first, 'Song calm'); // best calm match first
    // The badge label is merged into the tappable card's semantics node.
    expect(
      find.bySemanticsLabel(RegExp('Match score 100 out of 100')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('Relaxing filter hides energetic songs', (tester) async {
    await _pump(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Relaxing'));
    await tester.pumpAndSettle();

    expect(find.text('Song calm'), findsOneWidget);
    expect(find.text('Song loud'), findsNothing);
  });

  testWidgets('genre filter row appears when results span genres', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Rock'));
    await tester.pumpAndSettle();

    expect(find.text('Song loud'), findsOneWidget);
    expect(find.text('Song calm'), findsNothing);
    // No track is recent, so that filter is not offered.
    expect(find.widgetWithText(ChoiceChip, 'Recently released'), findsNothing);
  });

  testWidgets('adjusting mood re-ranks the list', (tester) async {
    final (container, _) = await _pump(tester);

    container.read(moodControllerProvider.notifier)
      ..toggle(Mood.calm)
      ..toggle(Mood.excited);
    await tester.pumpAndSettle();

    final first = tester
        .widgetList<Text>(find.textContaining('Song '))
        .first
        .data;
    expect(first, 'Song loud');
  });

  testWidgets('track details show the breakdown and open links', (
    tester,
  ) async {
    final (_, opened) = await _pump(tester);

    await tester.tap(find.text('Song calm'));
    await tester.pumpAndSettle();

    expect(find.text('Your mood'), findsOneWidget);
    expect(find.text('Scene atmosphere'), findsOneWidget);
    expect(find.text('not available'), findsNWidgets(3));
    expect(
      find.text('Previews are not available in demo mode.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Open in Spotify'));
    await tester.pump();
    expect(opened.single.host, 'open.spotify.com');
    expect(Uri.decodeComponent(opened.single.path), contains('Song calm'));
  });
}
