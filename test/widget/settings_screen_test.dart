import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moodscape/app/router.dart';
import 'package:moodscape/core/privacy/photo_consent.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/camera/application/captured_photo_controller.dart';
import 'package:moodscape/features/mood/application/mood_controller.dart';
import 'package:moodscape/features/mood/domain/mood.dart';
import 'package:moodscape/features/preferences/application/preferences_controller.dart';
import 'package:moodscape/features/settings/application/theme_controller.dart';
import 'package:moodscape/features/settings/presentation/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(ProviderContainer, SharedPreferences, FlutterSecureStorage)> _pump(
  WidgetTester tester,
) async {
  SharedPreferences.setMockInitialValues({
    MusicPreferencesController.storageKey: '{"genres": ["jazz"]}',
    'privacy.photo_upload_consent': true,
  });
  FlutterSecureStorage.setMockInitialValues({
    'spotify.tokens.v1':
        '{"access":"a","refresh":"r",'
        '"expiresAt":"2030-01-01T00:00:00Z","scopes":[]}',
  });
  final sp = await SharedPreferences.getInstance();
  const secure = FlutterSecureStorage();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
  );
  addTearDown(container.dispose);
  container.read(moodControllerProvider.notifier).toggle(Mood.calm);
  container
      .read(capturedPhotoProvider.notifier)
      .set(
        CapturedPhoto(
          bytes: Uint8List.fromList([1]),
          origin: PhotoOrigin.gallery,
        ),
      );

  final router = GoRouter(
    initialLocation: AppRoutes.settings,
    routes: [
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (_, _) => const Scaffold(body: Text('privacy-page')),
      ),
      GoRoute(
        path: AppRoutes.platform,
        builder: (_, _) => const Scaffold(body: Text('platform-page')),
      ),
    ],
  );
  addTearDown(router.dispose);
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (container, sp, secure);
}

void main() {
  testWidgets('theme choice is applied and remembered', (tester) async {
    final (c, sp, _) = await _pump(tester);
    expect(c.read(themeModeProvider), ThemeMode.dark);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    expect(c.read(themeModeProvider), ThemeMode.light);
    expect(sp.getString(ThemeModeController.storageKey), 'light');
  });

  testWidgets('upload consent can be changed back to "ask each time"', (
    tester,
  ) async {
    final (c, sp, _) = await _pump(tester);
    expect(c.read(photoUploadConsentProvider), isTrue);

    await tester.tap(find.text('Ask each time'));
    await tester.pumpAndSettle();

    expect(c.read(photoUploadConsentProvider), isNull);
    expect(sp.containsKey('privacy.photo_upload_consent'), isFalse);
  });

  testWidgets('shows honest service status in an unconfigured build', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Not set up in this build'), findsNWidgets(2));
    expect(find.text('None (demo catalogue)'), findsOneWidget);
  });

  testWidgets('cancelling "clear all data" keeps everything', (tester) async {
    final (c, sp, secure) = await _pump(tester);

    // The list builds lazily; scroll the item into existence first.
    await tester.scrollUntilVisible(
      find.text('Clear all data'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(sp.getKeys(), isNotEmpty);
    expect(await secure.readAll(), isNotEmpty);
    expect(c.read(capturedPhotoProvider), isNotNull);
  });

  testWidgets('confirming "clear all data" removes stored and in-memory data', (
    tester,
  ) async {
    final (c, sp, secure) = await _pump(tester);
    expect(c.read(musicPreferencesProvider).genres, isNotEmpty);

    // The list builds lazily; scroll the item into existence first.
    await tester.scrollUntilVisible(
      find.text('Clear all data'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear data'));
    await tester.pumpAndSettle();

    expect(sp.getKeys(), isEmpty);
    expect(await secure.readAll(), isEmpty);
    expect(c.read(capturedPhotoProvider), isNull);
    expect(c.read(moodControllerProvider).moods, isEmpty);
    expect(c.read(musicPreferencesProvider).genres, isEmpty);
    expect(c.read(photoUploadConsentProvider), isNull);
    expect(find.text('All MoodScape data was cleared.'), findsOneWidget);
  });
}
