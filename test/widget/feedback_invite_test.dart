import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moodscape/app/theme/app_theme.dart';
import 'package:moodscape/core/configuration/app_config.dart';
import 'package:moodscape/core/configuration/config_provider.dart';
import 'package:moodscape/core/l10n/app_language.dart';
import 'package:moodscape/core/links/url_opener.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/feedback/application/feedback_controller.dart';
import 'package:moodscape/features/feedback/presentation/feedback_invite.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _site = 'https://example.com/feedback/';

AppConfig _config(String feedbackUrl) => AppConfig(
  spotifyClientId: '',
  spotifyRedirectUri: '',
  analysisBackendUrl: '',
  appleMusicDeveloperTokenUrl: '',
  feedbackUrl: feedbackUrl,
);

/// Shows the invite with the real app theme (whose filled buttons are full
/// width by default) at phone size, a day after first use.
Future<(List<Uri>, SharedPreferences)> _pump(
  WidgetTester tester,
  Locale locale, {
  String feedbackUrl = _site,
  bool opens = true,
}) async {
  SharedPreferences.setMockInitialValues({
    FeedbackController.firstUseKey: DateTime(2026, 10, 1).toIso8601String(),
  });
  final prefs = await SharedPreferences.getInstance();
  final opened = <Uri>[];
  tester.view.physicalSize = const Size(360 * 3, 800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 3)),
        appConfigProvider.overrideWithValue(_config(feedbackUrl)),
        urlOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return opens;
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        locale: locale,
        supportedLocales: AppLanguage.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Scaffold(
          body: Padding(padding: EdgeInsets.all(16), child: FeedbackInvite()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (opened, prefs);
}

void main() {
  testWidgets('both buttons show and fit on a narrow phone', (tester) async {
    await _pump(tester, const Locale('en'));
    expect(tester.takeException(), isNull);
    expect(find.text('Later'), findsOneWidget);
    final rate = find.text('Rate MoodScape');
    expect(rate, findsOneWidget);
    expect(tester.getSize(rate).width, greaterThan(0));
    // Both fully on screen (side by side, or stacked when narrow).
    for (final f in [find.text('Later'), rate]) {
      expect(tester.getRect(f).right, lessThanOrEqualTo(360));
    }
  });

  testWidgets('fits in Thai too', (tester) async {
    await _pump(tester, const Locale('th'));
    expect(tester.takeException(), isNull);
    expect(find.text('ให้คะแนน MoodScape'), findsOneWidget);
    expect(find.text('ไว้ทีหลัง'), findsOneWidget);
  });

  testWidgets('Rate opens the feedback site', (tester) async {
    final (opened, prefs) = await _pump(tester, const Locale('en'));
    await tester.tap(find.text('Rate MoodScape'));
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse(_site)]);
    // Answering happens on the web, so the card must not come back.
    expect(prefs.getBool(FeedbackController.doneKey), isTrue);
    expect(find.text('Rate MoodScape'), findsNothing);
  });

  testWidgets('a site that will not open says so and keeps asking', (
    tester,
  ) async {
    final (opened, prefs) = await _pump(
      tester,
      const Locale('en'),
      opens: false,
    );
    await tester.tap(find.text('Rate MoodScape'));
    await tester.pumpAndSettle();
    expect(opened, hasLength(1));
    expect(find.text('Could not open the link.'), findsOneWidget);
    expect(prefs.getBool(FeedbackController.doneKey), isNull);
  });

  testWidgets('a build with no site says so rather than doing nothing', (
    tester,
  ) async {
    final (opened, _) = await _pump(
      tester,
      const Locale('en'),
      feedbackUrl: '',
    );
    await tester.tap(find.text('Rate MoodScape'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(find.text('Could not open the link.'), findsOneWidget);
  });

  testWidgets('Later hides the card', (tester) async {
    await _pump(tester, const Locale('en'));
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Rate MoodScape'), findsNothing);
  });
}
