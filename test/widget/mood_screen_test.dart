import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moodscape/app/router.dart';
import 'package:moodscape/features/mood/application/mood_controller.dart';
import 'package:moodscape/features/mood/domain/mood.dart';
import 'package:moodscape/features/mood/presentation/mood_screen.dart';

Future<ProviderContainer> _pumpMoodScreen(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: AppRoutes.mood,
    routes: [
      GoRoute(path: AppRoutes.mood, builder: (_, _) => const MoodScreen()),
      GoRoute(
        path: AppRoutes.preferences,
        builder: (_, _) => const Scaffold(body: Text('preferences-page')),
      ),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

FilledButton _continueButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'));

void main() {
  testWidgets('shows the question and every mood option', (tester) async {
    await _pumpMoodScreen(tester);

    expect(find.text('How are you feeling right now?'), findsOneWidget);
    for (final mood in Mood.values) {
      expect(find.widgetWithText(FilterChip, mood.label), findsOneWidget);
    }
  });

  testWidgets('Continue is disabled until a mood is picked', (tester) async {
    final container = await _pumpMoodScreen(tester);
    expect(_continueButton(tester).onPressed, isNull);

    await tester.tap(find.widgetWithText(FilterChip, 'Calm'));
    await tester.tap(find.widgetWithText(FilterChip, 'Focused'));
    await tester.pump();

    expect(container.read(moodControllerProvider).moods, {
      Mood.calm,
      Mood.focused,
    });
    expect(_continueButton(tester).onPressed, isNotNull);
  });

  testWidgets('description and intensity are optional inputs', (tester) async {
    final container = await _pumpMoodScreen(tester);

    expect(find.textContaining('not set'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  quiet morning ');
    await tester.pump();

    expect(container.read(moodControllerProvider).description, 'quiet morning');
    expect(container.read(moodControllerProvider).intensity, isNull);
  });

  testWidgets('Continue moves on to preferences', (tester) async {
    await _pumpMoodScreen(tester);

    await tester.tap(find.widgetWithText(FilterChip, 'Happy'));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Continue'));
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('preferences-page'), findsOneWidget);
  });
}
