import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moodscape/app/router.dart';
import 'package:moodscape/app/theme/app_theme.dart';
import 'package:moodscape/core/l10n/app_language.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/atmosphere/presentation/analysis_screen.dart';
import 'package:moodscape/features/camera/application/camera_providers.dart';
import 'package:moodscape/features/camera/presentation/capture_screen.dart';
import 'package:moodscape/features/feedback/presentation/feedback_screen.dart';
import 'package:moodscape/features/mood/application/mood_controller.dart';
import 'package:moodscape/features/mood/domain/mood.dart';
import 'package:moodscape/features/mood/presentation/mood_screen.dart';
import 'package:moodscape/features/music_platform/presentation/platform_screen.dart';
import 'package:moodscape/features/onboarding/presentation/privacy_screen.dart';
import 'package:moodscape/features/onboarding/presentation/welcome_screen.dart';
import 'package:moodscape/features/preferences/presentation/preferences_screen.dart';
import 'package:moodscape/features/activity/presentation/activity_screen.dart';
import 'package:moodscape/features/recommendations/application/recommendations_controller.dart';
import 'package:moodscape/features/recommendations/data/track_source.dart';
import 'package:moodscape/features/recommendations/domain/match_scorer.dart';
import 'package:moodscape/features/recommendations/domain/track.dart';
import 'package:moodscape/features/recommendations/presentation/results_screen.dart';
import 'package:moodscape/features/recommendations/presentation/track_detail_screen.dart';
import 'package:moodscape/features/settings/presentation/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Checks every main screen against Flutter's accessibility guidelines:
/// minimum tap-target sizes (Android 48dp, iOS 44pt), labelled tap targets
/// for screen readers, and WCAG text contrast — in dark and light themes,
/// and in Thai.

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
      album: 'Album',
      provider: MusicProvider.demo,
      valence: 65,
      energy: 25,
      releaseYear: 2020,
    ),
  ];
}

final _screens = <String, (String, Widget)>{
  'welcome': (AppRoutes.welcome, const WelcomeScreen()),
  'privacy': (AppRoutes.privacy, const PrivacyScreen()),
  'activity': (AppRoutes.activity, const ActivityScreen()),
  'feedback': (AppRoutes.feedback, const FeedbackScreen()),
  'capture': (AppRoutes.capture, const CaptureScreen()),
  'mood': (AppRoutes.mood, const MoodScreen()),
  'preferences': (AppRoutes.preferences, const PreferencesScreen()),
  'platform': (AppRoutes.platform, const PlatformScreen()),
  'analysis': (AppRoutes.analysis, const AnalysisScreen()),
  'results': (AppRoutes.results, const ResultsScreen()),
  'track details': ('/track', const TrackDetailScreen(trackId: 't1')),
  'settings': (AppRoutes.settings, const SettingsScreen()),
};

Future<void> _pump(
  WidgetTester tester,
  String name,
  ThemeMode mode,
  Locale locale,
) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      availableCamerasProvider.overrideWithValue(() async => []),
      trackSourceProvider.overrideWithValue(_Source()),
    ],
  );
  addTearDown(container.dispose);
  container.read(moodControllerProvider.notifier).toggle(Mood.calm);
  // Results must exist for the details screen.
  await container.read(recommendationsProvider.future);

  final (path, screen) = _screens[name]!;
  final router = GoRouter(
    initialLocation: path,
    routes: [GoRoute(path: path, builder: (_, _) => screen)],
  );
  addTearDown(router.dispose);

  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        locale: locale,
        supportedLocales: AppLanguage.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
      ),
    ),
  );
  // Bounded pumping: some screens animate continuously.
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  for (final (mode, locale) in [
    (ThemeMode.dark, const Locale('en')),
    (ThemeMode.light, const Locale('en')),
    (ThemeMode.dark, const Locale('th')),
  ]) {
    for (final name in _screens.keys) {
      testWidgets('$name meets accessibility guidelines '
          '(${mode.name}, ${locale.languageCode})', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, name, mode, locale);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        handle.dispose();
      });
    }
  }
}
