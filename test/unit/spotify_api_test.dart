import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moodscape/core/errors/app_failure.dart';
import 'package:moodscape/features/mood/domain/mood.dart';
import 'package:moodscape/features/preferences/domain/music_preferences.dart';
import 'package:moodscape/features/recommendations/domain/match_scorer.dart';
import 'package:moodscape/features/recommendations/domain/track.dart';
import 'package:moodscape/services/image_analysis/scene_features.dart';
import 'package:moodscape/services/spotify/spotify_api_client.dart';
import 'package:moodscape/services/spotify/spotify_auth_service.dart';
import 'package:moodscape/features/recommendations/domain/search_query_planner.dart';
import 'package:moodscape/services/spotify/spotify_track_mapper.dart';
import 'package:moodscape/services/spotify/spotify_track_source.dart';

class _MockDio extends Mock implements Dio {}

class _MockAuth extends Mock implements SpotifyAuthService {}

Map<String, Object?> _rawTrack(String id, {bool explicit = false}) => {
  'id': id,
  'name': 'Song $id',
  'uri': 'spotify:track:$id',
  'explicit': explicit,
  'artists': [
    {'name': 'A'},
    {'name': 'B'},
  ],
  'album': {
    'name': 'Album',
    'release_date': '2024-05-01',
    'images': [
      {'url': 'https://i.scdn.co/640.jpg', 'width': 640},
      {'url': 'https://i.scdn.co/300.jpg', 'width': 300},
      {'url': 'https://i.scdn.co/64.jpg', 'width': 64},
    ],
  },
  'external_urls': {'spotify': 'https://open.spotify.com/track/$id'},
  'preview_url': null,
};

DioException _status(int code, {Map<String, List<String>>? headers}) =>
    DioException(
      requestOptions: RequestOptions(),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(),
        statusCode: code,
        headers: Headers.fromMap(headers ?? {}),
      ),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(Options());
  });

  group('SpotifyApiClient', () {
    late _MockDio dio;
    late _MockAuth auth;
    late List<(String, Uri, Object?)> requests;
    late List<Object> replies;

    SpotifyApiClient client() => SpotifyApiClient(dio: dio, auth: auth);

    setUp(() {
      dio = _MockDio();
      auth = _MockAuth();
      requests = [];
      replies = [];
      when(
        () => auth.validAccessToken(forceRefresh: any(named: 'forceRefresh')),
      ).thenAnswer(
        (inv) async =>
            inv.namedArguments[#forceRefresh] == true ? 'fresh' : 'stale',
      );
      when(
        () => dio.requestUri<Object?>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((inv) async {
        final opts = inv.namedArguments[#options] as Options;
        requests.add((
          opts.method!,
          inv.positionalArguments.first as Uri,
          inv.namedArguments[#data],
        ));
        final r = replies.removeAt(0);
        if (r is DioException) throw r;
        return Response<Object?>(requestOptions: RequestOptions(), data: r);
      });
    });

    test('search caps limit at 10 and parses items', () async {
      replies.add({
        'tracks': {
          'items': [_rawTrack('1'), 'junk'],
        },
      });

      final items = await client().searchTracks('calm', limit: 50, offset: 10);

      expect(items, hasLength(1));
      final (method, uri, _) = requests.single;
      expect(method, 'GET');
      expect(uri.path, '/v1/search');
      expect(uri.queryParameters['limit'], '10');
      expect(uri.queryParameters['offset'], '10');
      expect(uri.queryParameters['type'], 'track');
    });

    test('401 refreshes the token once and retries', () async {
      replies.addAll([
        _status(401),
        {'display_name': 'Sam'},
      ]);

      expect(await client().displayName(), 'Sam');
      verify(() => auth.validAccessToken(forceRefresh: false)).called(1);
      verify(() => auth.validAccessToken(forceRefresh: true)).called(1);
    });

    test('second 401 becomes AuthFailure', () async {
      replies.addAll([_status(401), _status(401)]);
      await expectLater(client().displayName(), throwsA(isA<AuthFailure>()));
    });

    test('403 explains Development Mode allow-listing', () async {
      replies.add(_status(403));
      await expectLater(
        client().displayName(),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.message,
            'message',
            contains('Development Mode'),
          ),
        ),
      );
    });

    test('429 surfaces Retry-After', () async {
      replies.add(
        _status(
          429,
          headers: {
            'retry-after': ['7'],
          },
        ),
      );
      await expectLater(
        client().displayName(),
        throwsA(
          isA<NetworkFailure>().having(
            (e) => e.message,
            'message',
            contains('7'),
          ),
        ),
      );
    });

    test('creates playlists via /me/playlists and adds items in chunks of '
        '100 via /items', () async {
      replies.addAll([
        {
          'id': 'pl1',
          'external_urls': {'spotify': 'https://open.spotify.com/playlist/pl1'},
        },
        {},
        {},
        {},
      ]);

      final created = await client().createPlaylist(
        name: 'MoodScape',
        description: 'd',
      );
      await client().addItems(created.id, [
        for (var i = 0; i < 250; i++) 'spotify:track:$i',
      ]);

      expect(requests[0].$2.path, '/v1/me/playlists');
      expect((requests[0].$3 as Map)['public'], false);
      expect(
        [for (final r in requests.skip(1)) r.$2.path],
        [
          '/v1/playlists/pl1/items',
          '/v1/playlists/pl1/items',
          '/v1/playlists/pl1/items',
        ],
      );
      expect(
        [
          for (final r in requests.skip(1))
            ((r.$3 as Map)['uris'] as List).length,
        ],
        [100, 100, 50],
      );
    });

    test('SpotifyTrackSource dedupes across queries and pages', () async {
      // Every search returns the same two tracks.
      when(
        () => dio.requestUri<Object?>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Object?>(
          requestOptions: RequestOptions(),
          data: {
            'tracks': {
              'items': [_rawTrack('1'), _rawTrack('2')],
            },
          },
        ),
      );
      final source = SpotifyTrackSource(client());

      final tracks = await source.candidates(
        const MatchContext(
          mood: MoodInput(moods: {Mood.calm, Mood.happy}),
          preferences: MusicPreferences(),
        ),
      );

      expect(tracks.map((t) => t.id), ['1', '2']);
      expect(source.isDemo, isFalse);
      expect(source.notice, contains('estimated'));
    });
  });

  group('SpotifyTrackMapper', () {
    const features = EstimatedFeatures(
      valence: 60,
      energy: 30,
      genre: Genre.jazz,
      atmosphere: {SceneAtmosphere.cozy},
    );

    test('maps metadata and attaches estimated features', () {
      final t = SpotifyTrackMapper.fromJson(
        _rawTrack('x', explicit: true),
        features,
      )!;
      expect(t.title, 'Song x');
      expect(t.artist, 'A, B');
      expect(t.album, 'Album');
      expect(t.provider, MusicProvider.spotify);
      expect(t.providerUri, 'spotify:track:x');
      expect(t.releaseYear, 2024);
      expect(t.isExplicit, isTrue);
      expect(t.artworkUrl.toString(), 'https://i.scdn.co/300.jpg');
      expect(t.externalUrl.toString(), 'https://open.spotify.com/track/x');
      expect(t.previewUrl, isNull);
      expect(t.popularity, isNull); // removed from the API
      expect(t.genres, {Genre.jazz});
      expect((t.valence, t.energy), (60, 30));
    });

    test('rejects incomplete or non-track items', () {
      expect(
        SpotifyTrackMapper.fromJson({..._rawTrack('x'), 'id': null}, features),
        isNull,
      );
      expect(
        SpotifyTrackMapper.fromJson({
          ..._rawTrack('x'),
          'uri': 'spotify:episode:x',
        }, features),
        isNull,
      );
      expect(
        SpotifyTrackMapper.fromJson({
          ..._rawTrack('x'),
          'artists': [],
        }, features),
        isNull,
      );
    });

    test('ignores non-HTTPS links', () {
      final t = SpotifyTrackMapper.fromJson({
        ..._rawTrack('x'),
        'external_urls': {'spotify': 'http://insecure'},
      }, features)!;
      expect(t.externalUrl, isNull);
    });
  });

  group('SearchQueryPlanner (Spotify syntax)', () {
    SceneFeatures scene() => const SceneFeatures(
      setting: SceneSetting.outdoor,
      lighting: SceneLighting.soft,
      atmosphere: {SceneAtmosphere.cozy},
      cues: {EnvironmentalCue.rain},
      energy: 30,
      confidence: 0.8,
      source: AnalysisSource.mock,
    );

    test('combines mood, scene and genres; caps the number of queries', () {
      final qs = SearchQueryPlanner.plan(
        MatchContext(
          mood: const MoodInput(
            moods: {Mood.calm, Mood.nostalgic, Mood.focused, Mood.happy},
            description: 'my private diary entry',
          ),
          preferences: const MusicPreferences(
            genres: {Genre.jazz, Genre.lofi, Genre.rock},
          ),
          scene: scene(),
        ),
        genreTerm: SpotifyTrackSource.genreTerm,
      );
      final texts = qs.map((q) => q.text).toList();
      expect(texts.length, lessThanOrEqualTo(SearchQueryPlanner.maxQueries));
      // Up to three moods, in enum order; each gets a scene query before
      // any mood gets a genre query (round-robin).
      expect(texts.take(3), ['happy cozy', 'calm cozy', 'nostalgic cozy']);
      expect(texts.skip(3), [
        'happy genre:"rock"',
        'calm genre:"rock"',
        'nostalgic genre:"rock"',
      ]);
      expect(texts.join(' '), isNot(contains('diary')));
      expect(qs.first.features.atmosphere, {SceneAtmosphere.cozy});
      expect(qs.first.features.valence, isNotNull);
    });

    test('"Other" only falls back without inventing a mood target', () {
      final qs = SearchQueryPlanner.plan(
        const MatchContext(
          mood: MoodInput(moods: {Mood.other}),
          preferences: MusicPreferences(),
        ),
        genreTerm: SpotifyTrackSource.genreTerm,
      );
      expect(qs.single.text, 'chill');
      expect(qs.single.features.valence, isNull);
    });

    test('every mood except Other has a search word', () {
      for (final m in Mood.values.where((m) => m != Mood.other)) {
        expect(SearchQueryPlanner.moodWords[m], isNotNull, reason: m.name);
      }
      for (final g in Genre.values) {
        expect(SpotifyTrackSource.genreFilter[g], isNotNull, reason: g.name);
      }
    });
  });
}
