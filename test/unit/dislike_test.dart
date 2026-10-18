import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/mood/application/mood_controller.dart';
import 'package:moodscape/features/mood/domain/mood.dart';
import 'package:moodscape/features/music_platform/application/platform_providers.dart';
import 'package:moodscape/features/preferences/application/preferences_controller.dart';
import 'package:moodscape/features/preferences/domain/music_preferences.dart';
import 'package:moodscape/features/recommendations/application/disliked_tracks.dart';
import 'package:moodscape/features/recommendations/application/playlist_controller.dart';
import 'package:moodscape/features/recommendations/application/recommendations_controller.dart';
import 'package:moodscape/features/recommendations/data/track_source.dart';
import 'package:moodscape/features/recommendations/domain/match_scorer.dart';
import 'package:moodscape/features/recommendations/domain/track.dart';
import 'package:moodscape/services/spotify/spotify_api_client.dart';
import 'package:moodscape/services/spotify/spotify_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Source implements TrackSource {
  _Source(this.tracks);
  final List<Track> tracks;
  @override
  String get label => 'Test';
  @override
  bool get isDemo => true;
  @override
  String? get notice => null;
  @override
  Future<List<Track>> candidates(MatchContext ctx) async => tracks;
}

class _MockSpotify extends Mock implements SpotifyApiClient {}

class _MockDio extends Mock implements Dio {}

class _MockAuth extends Mock implements SpotifyAuthService {}

/// Calm target is valence 65 / energy 25; lower index = closer = higher score.
Track _t(int i, {MusicProvider provider = MusicProvider.demo}) => Track(
  id: 't$i',
  title: 'Song $i',
  artist: 'A',
  provider: provider,
  providerUri: 'spotify:track:t$i',
  valence: 65,
  energy: 25 + i * 5,
);

Future<ProviderContainer> _container(
  List<Track> tracks, {
  int playlistLength = 10,
  Map<String, Object> prefs = const {},
  List<Override> extra = const [],
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      trackSourceProvider.overrideWithValue(_Source(tracks)),
      ...extra,
    ],
  );
  addTearDown(c.dispose);
  c.read(moodControllerProvider.notifier).toggle(Mood.calm);
  await c
      .read(musicPreferencesProvider.notifier)
      .save(MusicPreferences(playlistLength: playlistLength));
  return c;
}

List<String> _ids(ProviderContainer c) => [
  for (final m in c.read(recommendationsProvider).value!.matches) m.track.id,
];

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(Options());
  });

  group('dislike', () {
    test('removes the song and adds the next best in its place', () async {
      final c = await _container([for (var i = 0; i < 15; i++) _t(i)]);
      await c.read(recommendationsProvider.future);
      expect(_ids(c), [for (var i = 0; i < 10; i++) 't$i']);

      final outcome = await c
          .read(recommendationsProvider.notifier)
          .dislike('t3');

      expect(outcome!.removed.track.id, 't3');
      expect(outcome.replacement!.track.id, 't10');
      expect(_ids(c), [
        't0',
        't1',
        't2',
        't4',
        't5',
        't6',
        't7',
        't8',
        't9',
        't10',
      ]);
    });

    test('is remembered across restarts and never comes back', () async {
      final tracks = [for (var i = 0; i < 15; i++) _t(i)];
      var c = await _container(tracks);
      await c.read(recommendationsProvider.future);
      await c.read(recommendationsProvider.notifier).dislike('t0');
      final sp = c.read(sharedPreferencesProvider);
      expect(sp.getStringList(DislikedTracksController.storageKey), ['t0']);

      // A "restart": fresh container over the same stored preferences.
      c = await _container(
        tracks,
        prefs: {
          DislikedTracksController.storageKey: ['t0'],
        },
      );
      await c.read(recommendationsProvider.future);
      expect(_ids(c), isNot(contains('t0')));

      // Even "new picks" with a small catalogue never brings it back.
      for (var i = 0; i < 3; i++) {
        c.read(recommendationsProvider.notifier).regenerate();
        expect(_ids(c), isNot(contains('t0')));
      }
    });

    test('with nothing left to suggest, the list just shrinks', () async {
      final c = await _container([_t(0), _t(1)]);
      await c.read(recommendationsProvider.future);

      final outcome = await c
          .read(recommendationsProvider.notifier)
          .dislike('t0');

      expect(outcome!.replacement, isNull);
      expect(_ids(c), ['t1']);
    });

    test('undo restores the song, removes its replacement and forgets the '
        'dislike', () async {
      final c = await _container([for (var i = 0; i < 12; i++) _t(i)]);
      await c.read(recommendationsProvider.future);
      final before = _ids(c);
      final ctrl = c.read(recommendationsProvider.notifier);

      final outcome = await ctrl.dislike('t2');
      await ctrl.undoDislike(outcome!);

      expect(_ids(c), before);
      expect(c.read(dislikedTracksProvider), isEmpty);
    });

    test('unknown ids are ignored', () async {
      final c = await _container([_t(0)]);
      await c.read(recommendationsProvider.future);
      expect(
        await c.read(recommendationsProvider.notifier).dislike('nope'),
        isNull,
      );
      expect(c.read(dislikedTracksProvider), isEmpty);
    });
  });

  group('Spotify playlist sync', () {
    test(
      'removeItems sends DELETE /playlists/{id}/items with item URIs',
      () async {
        final dio = _MockDio();
        final auth = _MockAuth();
        when(
          () => auth.validAccessToken(forceRefresh: any(named: 'forceRefresh')),
        ).thenAnswer((_) async => 'token');
        when(
          () => dio.requestUri<Object?>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(requestOptions: RequestOptions(), data: {}),
        );

        await SpotifyApiClient(
          dio: dio,
          auth: auth,
        ).removeItems('pl1', ['spotify:track:a']);

        final captured = verify(
          () => dio.requestUri<Object?>(
            captureAny(),
            data: captureAny(named: 'data'),
            options: captureAny(named: 'options'),
          ),
        ).captured;
        expect((captured[0] as Uri).path, '/v1/playlists/pl1/items');
        expect(captured[1], {
          'items': [
            {'uri': 'spotify:track:a'},
          ],
        });
        expect((captured[2] as Options).method, 'DELETE');
      },
    );

    Future<(ProviderContainer, _MockSpotify)> connected() async {
      final spotify = _MockSpotify();
      when(
        () => spotify.createPlaylist(
          name: any(named: 'name'),
          description: any(named: 'description'),
        ),
      ).thenAnswer((_) async => (id: 'pl1', url: null));
      when(() => spotify.addItems(any(), any())).thenAnswer((_) async {});
      when(() => spotify.removeItems(any(), any())).thenAnswer((_) async {});
      final c = await _container(
        [for (var i = 0; i < 3; i++) _t(i, provider: MusicProvider.spotify)],
        extra: [
          spotifyApiClientProvider.overrideWithValue(spotify),
          canSavePlaylistProvider.overrideWith((ref, _) => true),
        ],
      );
      return (c, spotify);
    }

    test('a disliked song is removed and its replacement added', () async {
      final (c, spotify) = await connected();
      final playlists = c.read(playlistControllerProvider.notifier);
      await playlists.saveAll([_t(0, provider: MusicProvider.spotify)]);

      final result = await playlists.swap(
        removed: _t(0, provider: MusicProvider.spotify),
        added: _t(1, provider: MusicProvider.spotify),
      );

      expect(result!.message, contains('Spotify playlist was updated'));
      verify(() => spotify.removeItems('pl1', ['spotify:track:t0'])).called(1);
      verify(() => spotify.addItems('pl1', ['spotify:track:t1'])).called(1);
    });

    test('nothing to sync before a playlist was saved', () async {
      final (c, spotify) = await connected();
      final result = await c
          .read(playlistControllerProvider.notifier)
          .swap(removed: _t(0, provider: MusicProvider.spotify));
      expect(result, isNull);
      verifyNever(() => spotify.removeItems(any(), any()));
    });
  });
}
