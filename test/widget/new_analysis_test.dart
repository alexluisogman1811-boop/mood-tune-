import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moodscape/app/router.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/activity/application/activity_controller.dart';
import 'package:moodscape/features/activity/domain/activity.dart';
import 'package:moodscape/features/activity/presentation/activity_screen.dart';
import 'package:moodscape/features/camera/application/captured_photo_controller.dart';
import 'package:moodscape/features/mood/application/mood_controller.dart';
import 'package:moodscape/features/mood/domain/mood.dart';
import 'package:moodscape/features/preferences/application/preferences_controller.dart';
import 'package:moodscape/features/preferences/domain/music_preferences.dart';
import 'package:moodscape/features/recommendations/application/recommendations_controller.dart';
import 'package:moodscape/features/recommendations/data/track_source.dart';
import 'package:moodscape/features/recommendations/domain/match_scorer.dart';
import 'package:moodscape/features/recommendations/domain/track.dart';
import 'package:moodscape/features/recommendations/presentation/results_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Source implements TrackSource {
  @override
  String get label => 'Test catalogue';
  @override
  bool get isDemo => true;
  @override
  String? get notice => null;
  @override
  Future<List<Track>> candidates(MatchContext ctx) async => const [
    Track(
      id: 't1',
      title: 'Quiet Morning',
      artist: 'Test Artist',
      provider: MusicProvider.demo,
      valence: 65,
      energy: 25,
    ),
  ];
}

void main() {
  testWidgets('New analysis starts over in one tap, keeping preferences', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'music_preferences.v1': '{"genres": ["jazz"]}',
    });
    final sp = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        trackSourceProvider.overrideWithValue(_Source()),
      ],
    );
    addTearDown(c.dispose);
    c.read(moodControllerProvider.notifier).toggle(Mood.calm);
    c.read(activityProvider.notifier).set(Activity.reading);
    c
        .read(capturedPhotoProvider.notifier)
        .set(CapturedPhoto(bytes: Uint8List(4), origin: PhotoOrigin.gallery));

    final router = GoRouter(
      initialLocation: AppRoutes.results,
      routes: [
        GoRoute(
          path: AppRoutes.welcome,
          builder: (_, _) => const Scaffold(body: Text('welcome')),
        ),
        GoRoute(
          path: AppRoutes.activity,
          builder: (_, _) => const ActivityScreen(),
        ),
        GoRoute(
          path: AppRoutes.results,
          builder: (_, _) => const ResultsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New analysis'));
    await tester.pumpAndSettle();

    expect(find.text('What are you doing?'), findsOneWidget);
    expect(c.read(activityProvider), isNull);
    expect(c.read(capturedPhotoProvider), isNull);
    expect(c.read(moodControllerProvider).moods, isEmpty);
    expect(c.read(musicPreferencesProvider).genres, {Genre.jazz});

    // Back goes home, not to the old results.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('welcome'), findsOneWidget);
  });
}
