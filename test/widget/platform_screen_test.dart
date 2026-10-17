import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moodscape/app/router.dart';
import 'package:moodscape/core/configuration/app_config.dart';
import 'package:moodscape/core/configuration/config_provider.dart';
import 'package:moodscape/core/network/dio_provider.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/music_platform/application/platform_providers.dart';
import 'package:moodscape/features/music_platform/presentation/platform_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDio extends Mock implements Dio {}

AppConfig _config({bool spotify = false}) => AppConfig(
  spotifyClientId: spotify ? 'client' : '',
  spotifyRedirectUri: spotify ? 'moodscape://spotify-callback' : '',
  analysisBackendUrl: '',
  appleMusicDeveloperTokenUrl: '',
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  bool spotify = false,
  Dio? dio,
}) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      appConfigProvider.overrideWithValue(_config(spotify: spotify)),
      if (dio != null) dioProvider.overrideWithValue(dio),
      webAuthLauncherProvider.overrideWithValue(
        (url, scheme) async =>
            '$scheme://spotify-callback?code=c&state=${url.queryParameters['state']}',
      ),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: AppRoutes.platform,
    routes: [
      GoRoute(
        path: AppRoutes.platform,
        builder: (_, _) => const PlatformScreen(),
      ),
      GoRoute(
        path: AppRoutes.analysis,
        builder: (_, _) => const Scaffold(body: Text('analysis-page')),
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
  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(Options());
  });

  testWidgets('unconfigured build shows setup help, never "connected"', (
    tester,
  ) async {
    await _pump(tester);

    // Both Spotify and Apple Music explain their setup.
    expect(find.textContaining('not set up in this build'), findsNWidgets(2));
    expect(find.text('Connect'), findsNothing);
    expect(find.textContaining('Connected'), findsNothing);
  });

  testWidgets('choosing a platform is remembered separately from auth', (
    tester,
  ) async {
    final c = await _pump(tester);

    await tester.tap(find.text('Spotify'));
    await tester.pump();

    expect(c.read(selectedPlatformProvider), MusicPlatform.spotify);
    expect(c.read(spotifyConnectionProvider).value!.connected, isFalse);
  });

  testWidgets('connect → connected → disconnect', (tester) async {
    final dio = _MockDio();
    when(
      () => dio.postUri<Object?>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(),
        data: {'access_token': 'AT', 'refresh_token': 'RT', 'expires_in': 3600},
      ),
    );
    when(
      () => dio.requestUri<Object?>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(),
        data: {'display_name': 'Sam'},
      ),
    );
    final c = await _pump(tester, spotify: true, dio: dio);

    expect(find.text('Not connected'), findsOneWidget);
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.text('Connected as Sam'), findsOneWidget);
    expect(c.read(selectedPlatformProvider), MusicPlatform.spotify);

    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();

    expect(find.text('Not connected'), findsOneWidget);
    expect(
      await c.read(spotifyTokenStoreProvider).read(),
      isNull,
      reason: 'tokens must be removed on disconnect',
    );
  });

  testWidgets('a failed connection shows an error and stays disconnected', (
    tester,
  ) async {
    final dio = _MockDio();
    when(
      () => dio.postUri<Object?>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      ),
    );
    await _pump(tester, spotify: true, dio: dio);

    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.text('Could not reach Spotify. Try again.'), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);
  });
}
