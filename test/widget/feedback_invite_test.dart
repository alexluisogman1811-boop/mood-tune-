import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moodscape/app/theme/app_theme.dart';
import 'package:moodscape/core/l10n/app_language.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/feedback/application/feedback_controller.dart';
import 'package:moodscape/features/feedback/presentation/feedback_invite.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shows the invite with the real app theme (whose filled buttons are full
/// width by default) at phone size, a day after first use.
Future<void> _pump(WidgetTester tester, Locale locale) async {
  SharedPreferences.setMockInitialValues({
    FeedbackController.firstUseKey: DateTime(2026, 10, 1).toIso8601String(),
  });
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(
          body: Padding(padding: EdgeInsets.all(16), child: FeedbackInvite()),
        ),
      ),
      GoRoute(
        path: '/feedback',
        builder: (_, _) => const Scaffold(body: Text('feedback screen')),
      ),
    ],
  );
  addTearDown(router.dispose);
  tester.view.physicalSize = const Size(360 * 3, 800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 3)),
      ],
      child: MaterialApp.router(
        theme: AppTheme.dark(),
        locale: locale,
        supportedLocales: AppLanguage.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
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

  testWidgets('Rate opens the feedback screen', (tester) async {
    await _pump(tester, const Locale('en'));
    await tester.tap(find.text('Rate MoodScape'));
    await tester.pumpAndSettle();
    expect(find.text('feedback screen'), findsOneWidget);
  });

  testWidgets('Later hides the card', (tester) async {
    await _pump(tester, const Locale('en'));
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Rate MoodScape'), findsNothing);
  });
}
