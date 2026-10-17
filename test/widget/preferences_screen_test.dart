import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moodscape/app/router.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/preferences/application/preferences_controller.dart';
import 'package:moodscape/features/preferences/domain/music_preferences.dart';
import 'package:moodscape/features/preferences/presentation/preferences_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
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
    await tester.scrollUntilVisible(find.text('Relaxing'), 200);
    await tester.tap(find.text('Relaxing'));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Save and continue'), 200);
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

    await tester.scrollUntilVisible(find.text('Energetic'), 200);
    await tester.tap(find.text('Energetic'));
    await tester.pump();
    await tester.tap(find.text('Energetic'));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Save and continue'), 200);
    await tester.tap(find.text('Save and continue'));
    await tester.pumpAndSettle();

    expect(c.read(musicPreferencesProvider).energy, isNull);
  });
}
