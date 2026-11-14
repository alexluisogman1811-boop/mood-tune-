import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moodscape/app/router.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/preferences/application/artist_catalog.dart';
import 'package:moodscape/features/preferences/application/preferences_controller.dart';
import 'package:moodscape/features/preferences/domain/music_preferences.dart';
import 'package:moodscape/features/preferences/presentation/preferences_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The page's own list. The band search box brings a second scrollable of
/// its own, so scrolling has to say which one it means.
Finder _list() => find.byType(Scrollable).first;

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<CatalogArtist>? artists,
}) async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      if (artists != null)
        artistCatalogProvider.overrideWith((ref) async => artists),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: AppRoutes.preferences,
    routes: [
      GoRoute(
        path: AppRoutes.preferences,
        builder: (_, _) => const PreferencesScreen(),
      ),
      GoRoute(
        path: AppRoutes.platform,
        builder: (_, _) => const Scaffold(body: Text('platform-page')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('Skip continues without saving anything', (tester) async {
    final c = await _pump(tester);

    await tester.tap(find.text('Jazz'));
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('platform-page'), findsOneWidget);
    expect(c.read(musicPreferencesProvider).genres, isEmpty);
  });

  testWidgets('Save and continue stores the chosen preferences', (
    tester,
  ) async {
    final c = await _pump(tester);

    await tester.tap(find.text('Jazz'));
    await tester.scrollUntilVisible(
      find.text('Relaxing'),
      200,
      scrollable: _list(),
    );
    await tester.tap(find.text('Relaxing'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Save and continue'),
      200,
      scrollable: _list(),
    );
    await tester.tap(find.text('Allow explicit content'));
    await tester.pump();
    await tester.tap(find.text('Save and continue'));
    await tester.pumpAndSettle();

    final p = c.read(musicPreferencesProvider);
    expect(p.genres, {Genre.jazz});
    expect(p.energy, EnergyPreference.relaxing);
    expect(p.allowExplicit, isFalse);
    expect(find.text('platform-page'), findsOneWidget);
  });

  testWidgets('energy can be cleared by tapping again', (tester) async {
    final c = await _pump(tester);

    await tester.scrollUntilVisible(
      find.text('Energetic'),
      200,
      scrollable: _list(),
    );
    await tester.tap(find.text('Energetic'));
    await tester.pump();
    await tester.tap(find.text('Energetic'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Save and continue'),
      200,
      scrollable: _list(),
    );
    await tester.tap(find.text('Save and continue'));
    await tester.pumpAndSettle();

    expect(c.read(musicPreferencesProvider).energy, isNull);
  });

  testWidgets('a band can be searched for, picked and kept', (tester) async {
    final c = await _pump(
      tester,
      artists: const [
        CatalogArtist(
          name: 'Bodyslam',
          songs: 14,
          language: MusicLanguage.thai,
        ),
        CatalogArtist(name: 'BTS', songs: 66, language: MusicLanguage.korean),
      ],
    );

    await tester.scrollUntilVisible(
      find.text('Search for a band'),
      200,
      scrollable: _list(),
    );
    await tester.enterText(find.byType(TextField), 'body');
    await tester.pumpAndSettle();
    expect(find.textContaining('BTS'), findsNothing);

    await tester.tap(find.textContaining('Bodyslam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Only these bands'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Save and continue'),
      200,
      scrollable: _list(),
    );
    await tester.tap(find.text('Save and continue'));
    await tester.pumpAndSettle();

    final p = c.read(musicPreferencesProvider);
    expect(p.artists, {'Bodyslam'});
    expect(p.artistsOnly, isTrue);
  });
}
