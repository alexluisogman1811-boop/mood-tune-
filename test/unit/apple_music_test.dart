import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moodscape/core/configuration/app_config.dart';
import 'package:moodscape/core/configuration/config_provider.dart';
import 'package:moodscape/core/errors/app_failure.dart';
import 'package:moodscape/core/network/dio_provider.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/mood/domain/mood.dart';
import 'package:moodscape/features/music_platform/application/apple_music_providers.dart';
import 'package:moodscape/features/music_platform/application/platform_providers.dart';
import 'package:moodscape/features/preferences/domain/music_preferences.dart';
import 'package:moodscape/features/recommendations/application/recommendations_controller.dart';
import 'package:moodscape/features/recommendations/domain/match_scorer.dart';
import 'package:moodscape/features/recommendations/domain/search_query_planner.dart';
import 'package:moodscape/features/recommendations/domain/track.dart';
import 'package:moodscape/services/apple_music/apple_music_api_client.dart';
import 'package:moodscape/services/apple_music/apple_music_tokens.dart';
import 'package:moodscape/services/apple_music/apple_music_track_mapper.dart';
import 'package:moodscape/services/apple_music/apple_music_track_source.dart';
import 'package:moodscape/services/apple_music/musickit_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDio extends Mock implements Dio {}

class _FakeBridge implements MusicKitBridge {
  _FakeBridge({
    this.isSupported = true,
    this.status = MusicKitAuthStatus.authorized,
    this.canPlay = true,
  });

  @override
  final bool isSupported;
  MusicKitAuthStatus status;
  bool canPlay;
  int developerTokenCalls = 0;

  @override
  Future<MusicKitAuthStatus> authorizationStatus() async => status;

  @override
  Future<MusicKitAuthStatus> requestAuthorization() async => status;

  @override
  Future<String> developerToken() async {
    developerTokenCalls++;
    return _jwt(DateTime.utc(2030));
  }

  @override
  Future<String> userToken(String developerToken) async => 'user-token';

  @override
  Future<({bool canPlayCatalog, bool canBecomeSubscriber})>
  subscription() async =>
      (canPlayCatalog: canPlay, canBecomeSubscriber: !canPlay);
}

String _jwt(DateTime exp) {
  String part(Map<String, Object> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'ES256'})}.'
      '${part({'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

Map<String, Object?> _song(
  String id, {
  String? rating,
  List<String> genres = const ['Jazz', 'Music'],
}) => {
  'id': id,
  'type': 'songs',
  'attributes': {
    'name': 'Song $id',
    'artistName': 'Artist',
    'albumName': 'Album',
    'genreNames': genres,
    'releaseDate': '2022-07-22',
    'url': 'https://music.apple.com/us/album/x/1?i=$id',
    'artwork': {
      'url': 'https://is1-ssl.mzstatic.com/image/thumb/a.jpg/{w}x{h}bb.jpg',
    },
    'previews': [
      {'url': 'https://audio-ssl.itunes.apple.com/p.m4a'},
    ],
    'contentRating': ?rating,
  },
};

DioException _status(int code) => DioException(
  requestOptions: RequestOptions(),
  type: DioExceptionType.badResponse,
  response: Response(requestOptions: RequestOptions(), statusCode: code),
);

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(Options());
  });

  group('developer tokens', () {
    test('reads the JWT exp claim', () {
      expect(
        AppleDeveloperTokenProvider.jwtExpiry(_jwt(DateTime.utc(2027, 1, 2))),
        DateTime.utc(2027, 1, 2),
      );
      expect(AppleDeveloperTokenProvider.jwtExpiry('not.a.jwt'), isNull);
    });

    test('iOS uses native MusicKit and caches until near expiry', () async {
      final bridge = _FakeBridge();
      final p = AppleDeveloperTokenProvider(
        native: bridge,
        dio: _MockDio(),
        clock: () => DateTime.utc(2026),
      );
      await p.token();
      await p.token();
      expect(bridge.developerTokenCalls, 1);
      p.invalidate();
      await p.token();
      expect(bridge.developerTokenCalls, 2);
    });

    test('elsewhere needs an HTTPS backend', () async {
      final none = AppleDeveloperTokenProvider(
        native: _FakeBridge(isSupported: false),
        dio: _MockDio(),
        backendUrl: Uri.parse('http://insecure.test/token'),
      );
      expect(none.isAvailable, isFalse);
      await expectLater(none.token(), throwsA(isA<NotConfiguredFailure>()));

      final dio = _MockDio();
      when(() => dio.getUri<Object?>(any())).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {'token': _jwt(DateTime.utc(2030))},
        ),
      );
      final backend = AppleDeveloperTokenProvider(
        native: _FakeBridge(isSupported: false),
        dio: dio,
        backendUrl: Uri.parse('https://tokens.test/apple'),
      );
      expect(backend.isAvailable, isTrue);
      expect((await backend.token()).split('.'), hasLength(3));
    });

    test('rejects a malformed backend token', () async {
      final dio = _MockDio();
      when(() => dio.getUri<Object?>(any())).thenAnswer(
        (_) async =>
            Response(requestOptions: RequestOptions(), data: {'token': 'nope'}),
      );
      final p = AppleDeveloperTokenProvider(
        native: _FakeBridge(isSupported: false),
        dio: dio,
        backendUrl: Uri.parse('https://tokens.test/apple'),
      );
      await expectLater(p.token(), throwsA(isA<InvalidResponseFailure>()));
    });
  });

  group('AppleMusicApiClient', () {
    late _MockDio dio;
    late AppleMusicUserTokenStore userTokens;
    late List<(Uri, Options, Object?)> requests;
    late List<Object> replies;

    AppleMusicApiClient client() => AppleMusicApiClient(
      dio: dio,
      developerTokens: AppleDeveloperTokenProvider(
        native: _FakeBridge(),
        dio: dio,
        clock: () => DateTime.utc(2026),
      ),
      userTokens: userTokens,
    );

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      userTokens = const AppleMusicUserTokenStore(FlutterSecureStorage());
      dio = _MockDio();
      requests = [];
      replies = [];
      when(
        () => dio.requestUri<Object?>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((inv) async {
        requests.add((
          inv.positionalArguments.first as Uri,
          inv.namedArguments[#options] as Options,
          inv.namedArguments[#data],
        ));
        final r = replies.removeAt(0);
        if (r is DioException) throw r;
        return Response<Object?>(requestOptions: RequestOptions(), data: r);
      });
    });

    test('catalogue search uses the storefront and caps limit at 25', () async {
      replies.add({
        'results': {
          'songs': {
            'data': [_song('1')],
          },
        },
      });

      final songs = await client().searchSongs(
        'calm jazz',
        storefront: 'gb',
        limit: 100,
      );

      expect(songs, hasLength(1));
      final (uri, opts, _) = requests.single;
      expect(uri.host, 'api.music.apple.com');
      expect(uri.path, '/v1/catalog/gb/search');
      expect(uri.queryParameters['types'], 'songs');
      expect(uri.queryParameters['limit'], '25');
      expect(opts.headers!.containsKey('Music-User-Token'), isFalse);
    });

    test('no "songs" key means no results, not an error', () async {
      replies.add({'results': <String, Object>{}});
      expect(await client().searchSongs('x', storefront: 'us'), isEmpty);
    });

    test('invalid storefront is rejected before any request', () async {
      await expectLater(
        client().searchSongs('x', storefront: '../me'),
        throwsA(isA<InvalidResponseFailure>()),
      );
      expect(requests, isEmpty);
    });

    test('library calls need a user token', () async {
      await expectLater(
        client().createLibraryPlaylist(
          name: 'n',
          description: 'd',
          songIds: ['1'],
        ),
        throwsA(isA<AuthFailure>()),
      );
      expect(requests, isEmpty);
    });

    test('creates a library playlist with catalogue songs', () async {
      await userTokens.write('user-token');
      replies.add({
        'data': [
          {'id': 'p.123', 'type': 'library-playlists'},
        ],
      });

      final id = await client().createLibraryPlaylist(
        name: 'MoodScape',
        description: 'd',
        songIds: ['1', '2'],
      );

      expect(id, 'p.123');
      final (uri, opts, body) = requests.single;
      expect(uri.path, '/v1/me/library/playlists');
      expect(opts.method, 'POST');
      expect(opts.headers!['Music-User-Token'], 'user-token');
      final tracks = ((body as Map)['relationships'] as Map)['tracks'] as Map;
      expect(tracks['data'], [
        {'id': '1', 'type': 'songs'},
        {'id': '2', 'type': 'songs'},
      ]);
    });

    test('revoked user token is cleared and reported', () async {
      await userTokens.write('user-token');
      replies.add(_status(401));

      await expectLater(
        client().addToLibraryPlaylist('p.1', ['1']),
        throwsA(isA<AuthFailure>()),
      );
      expect(await userTokens.read(), isNull);
    });

    test('403 on library explains the subscription requirement', () async {
      await userTokens.write('user-token');
      replies.add(_status(403));
      await expectLater(
        client().addToLibraryPlaylist('p.1', ['1']),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.message,
            'message',
            contains('subscription'),
          ),
        ),
      );
      expect(await userTokens.read(), isNotNull);
    });
  });

  group('AppleMusicTrackMapper', () {
    const f = EstimatedFeatures(valence: 60, energy: 30);

    test('maps real metadata and fills the artwork template', () {
      final t = AppleMusicTrackMapper.fromJson(
        _song('9', rating: 'explicit'),
        f,
      )!;
      expect(t.provider, MusicProvider.appleMusic);
      expect(t.providerUri, '9');
      expect(t.genres, {Genre.jazz});
      expect(t.releaseYear, 2022);
      expect(t.isExplicit, isTrue);
      expect(t.artworkUrl.toString(), endsWith('/300x300bb.jpg'));
      expect(t.previewUrl!.host, 'audio-ssl.itunes.apple.com');
      expect(t.externalUrl!.host, 'music.apple.com');
      expect((t.valence, t.energy), (60, 30));
    });

    test('content rating: clean → false, missing → unknown', () {
      expect(
        AppleMusicTrackMapper.fromJson(
          _song('1', rating: 'clean'),
          f,
        )!.isExplicit,
        isFalse,
      );
      expect(AppleMusicTrackMapper.fromJson(_song('1'), f)!.isExplicit, isNull);
    });

    test('maps Apple genre names', () {
      expect(
        AppleMusicTrackMapper.genresFrom([
          'Hip-Hop/Rap',
          'R&B/Soul',
          'K-Pop',
          'Singer/Songwriter',
          'Alternative',
          'Música Mexicana',
        ]),
        {
          Genre.hipHop,
          Genre.rnb,
          Genre.soul,
          Genre.kpop,
          Genre.folk,
          Genre.indie,
        },
      );
    });

    test('rejects non-song resources', () {
      expect(
        AppleMusicTrackMapper.fromJson({..._song('1'), 'type': 'albums'}, f),
        isNull,
      );
    });
  });

  group('connection and source selection', () {
    Future<ProviderContainer> container(
      _FakeBridge bridge, {
      String tokenUrl = '',
    }) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sp),
          musicKitBridgeProvider.overrideWithValue(bridge),
          dioProvider.overrideWithValue(_MockDio()),
          deviceStorefrontProvider.overrideWithValue('th'),
          appConfigProvider.overrideWithValue(
            AppConfig(
              spotifyClientId: '',
              spotifyRedirectUri: '',
              analysisBackendUrl: '',
              appleMusicDeveloperTokenUrl: tokenUrl,
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('iOS: connect stores a user token; disconnect removes it', () async {
      final c = await container(_FakeBridge());
      final ctrl = c.read(appleMusicConnectionProvider.notifier);
      await c.read(appleMusicConnectionProvider.future);

      expect(await ctrl.connect(), isNull);
      final conn = c.read(appleMusicConnectionProvider).value!;
      expect(conn.authorized, isTrue);
      expect(conn.canPlayCatalog, isTrue);
      expect(
        await c.read(appleMusicUserTokenStoreProvider).read(),
        'user-token',
      );

      await ctrl.disconnect();
      expect(c.read(appleMusicConnectionProvider).value!.authorized, isFalse);
      expect(await c.read(appleMusicUserTokenStoreProvider).read(), isNull);
    });

    test('connected without a subscription is reported, not hidden', () async {
      final c = await container(_FakeBridge(canPlay: false));
      await c.read(appleMusicConnectionProvider.future);

      expect(
        await c.read(appleMusicConnectionProvider.notifier).connect(),
        isNull,
      );
      expect(
        c.read(appleMusicConnectionProvider).value!.canPlayCatalog,
        isFalse,
      );
    });

    test('denied permission is reported and nothing is stored', () async {
      final c = await container(_FakeBridge(status: MusicKitAuthStatus.denied));
      await c.read(appleMusicConnectionProvider.future);

      final msg = await c.read(appleMusicConnectionProvider.notifier).connect();

      expect(msg, contains('not allowed'));
      expect(await c.read(appleMusicUserTokenStoreProvider).read(), isNull);
    });

    test('Android: catalogue via token backend, library unsupported', () async {
      final c = await container(
        _FakeBridge(isSupported: false),
        tokenUrl: 'https://tokens.test/apple',
      );
      final conn = await c.read(appleMusicConnectionProvider.future);
      expect(conn.catalogAvailable, isTrue);
      expect(conn.librarySupported, isFalse);
      expect(
        await c.read(appleMusicConnectionProvider.notifier).connect(),
        contains('iOS'),
      );

      await c
          .read(selectedPlatformProvider.notifier)
          .select(MusicPlatform.appleMusic);
      final source = c.read(trackSourceProvider);
      expect(source, isA<AppleMusicTrackSource>());
      expect((source as AppleMusicTrackSource).fallbackStorefront, 'th');
    });

    test(
      'Android without a backend falls back to the demo catalogue',
      () async {
        final c = await container(_FakeBridge(isSupported: false));
        await c
            .read(selectedPlatformProvider.notifier)
            .select(MusicPlatform.appleMusic);
        expect(c.read(trackSourceProvider).isDemo, isTrue);
        expect(c.read(appleMusicApiClientProvider), isNull);
      },
    );

    test('Apple Music search terms use plain genre words', () {
      final qs = SearchQueryPlanner.plan(
        const MatchContext(
          mood: MoodInput(moods: {Mood.calm}),
          preferences: MusicPreferences(genres: {Genre.hipHop}),
        ),
        genreTerm: AppleMusicTrackSource.genreTerm,
      );
      expect(qs.map((q) => q.text), contains('calm hip-hop'));
    });
  });
}
