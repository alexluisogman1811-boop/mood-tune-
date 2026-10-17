import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moodscape/app/app.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/camera/application/camera_providers.dart';
import 'package:moodscape/features/preferences/application/preferences_controller.dart';
import 'package:moodscape/features/preferences/domain/music_preferences.dart';
import 'package:moodscape/features/recommendations/application/recommendations_controller.dart';
import 'package:moodscape/features/recommendations/data/track_links.dart';
import 'package:moodscape/features/recommendations/presentation/track_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// End-to-end run of the real app on a device or emulator:
///
/// ```
/// flutter test integration_test -d <device-id>
/// ```
///
/// Storage is in-memory so the test never touches data from manual use of
/// the app, the camera is reported as absent so no permission dialog blocks
/// the run, and external links are recorded instead of launched. Everything
/// else — routing, the demo catalogue asset, scoring and UI — is real.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late List<Uri> opened;
  late ProviderContainer container;

  Future<void> launchApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    opened = [];
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        availableCamerasProvider.overrideWithValue(() async => []),
        urlOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MoodScapeApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Pumps frames until [finder] matches, for screens with ongoing
  /// animations or real async work (asset loading, isolates).
  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final end = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty) {
      if (DateTime.now().isAfter(end)) {
        fail('Timed out waiting for $finder');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Scrolls the screen's main list until [finder] is built and visible.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
    }
  }

  /// Taps [text], scrolling the screen's main list first if needed: lazily
  /// built lists don't create off-screen widgets, so they can't be found
  /// until scrolled into range.
  Future<void> tapText(WidgetTester tester, String text) async {
    final all = find.text(text);
    if (all.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        all,
        300,
        scrollable: find.byType(Scrollable).first,
      );
    }
    final f = all.first;
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('full journey: welcome → mood → preferences → results → '
      'details → settings', (tester) async {
    await launchApp(tester);

    // Welcome.
    expect(find.text('MoodScape'), findsOneWidget);
    await tapText(tester, 'Get Started');

    // Capture: no camera on this "device", photo is optional.
    await pumpUntil(tester, find.text('No camera was found on this device.'));
    await tapText(tester, 'Continue without a photo');

    // Mood: several moods plus intensity left unset.
    expect(find.text('How are you feeling right now?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Calm'));
    await tester.tap(find.widgetWithText(FilterChip, 'Nostalgic'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Continue');

    // Preferences: pick a genre and a relaxing energy, then save.
    await pumpUntil(tester, find.text('Favourite genres'));
    await tapText(tester, 'Jazz');
    await tapText(tester, 'Relaxing');
    await tapText(tester, 'Save and continue');
    final prefs = container.read(musicPreferencesProvider);
    expect(prefs.genres, {Genre.jazz});
    expect(prefs.energy, EnergyPreference.relaxing);

    // Platform: nothing configured in this build → demo catalogue.
    await pumpUntil(tester, find.text('Where do you listen?'));
    await tapText(tester, 'Continue');

    // Atmosphere: no photo, so analysis is skipped with an explanation.
    await pumpUntil(tester, find.textContaining('mood only'));
    await tapText(tester, 'See my music');

    // Results: real demo catalogue, scored on device.
    await pumpUntil(tester, find.byType(TrackCard));
    expect(find.text('Demo mode'), findsOneWidget);
    expect(find.textContaining('not a scientific measure'), findsOneWidget);
    // The list is lazy, so check the full ranking via app state and the
    // first visible card via the UI.
    final matches = container.read(recommendationsProvider).value!.matches;
    expect(matches.length, 20); // default playlist length, catalogue has more
    final scores = [for (final m in matches) m.score];
    expect(scores, orderedEquals([...scores]..sort((a, b) => b - a)));
    expect(scores, everyElement(inInclusiveRange(0, 100)));
    final topCard = tester.widget<TrackCard>(find.byType(TrackCard).first);
    expect(topCard.match.track.id, matches.first.track.id);

    // Filters.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Relaxing'));
    await tester.pumpAndSettle();
    for (final c in tester.widgetList<TrackCard>(find.byType(TrackCard))) {
      expect(c.match.track.energy, lessThanOrEqualTo(45));
    }

    // Details with score breakdown and an "open in" link.
    final first = tester.widget<TrackCard>(find.byType(TrackCard).first);
    await tester.tap(find.byType(TrackCard).first);
    await tester.pumpAndSettle();
    expect(find.text(first.match.track.title), findsOneWidget);
    expect(find.text('Your mood'), findsOneWidget);
    final previewNote = find.text('Previews are not available in demo mode.');
    await scrollTo(tester, previewNote);
    expect(previewNote, findsOneWidget);
    await tapText(tester, 'Open in Spotify');
    expect(opened.single.host, 'open.spotify.com');

    // Back to results, then Settings → clear all data.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Clear all data');
    await tapText(tester, 'Clear data');
    expect(find.text('All MoodScape data was cleared.'), findsOneWidget);
    expect(container.read(musicPreferencesProvider).genres, isEmpty);
  });
}
