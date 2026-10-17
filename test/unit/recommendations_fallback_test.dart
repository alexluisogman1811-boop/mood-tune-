import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodscape/core/errors/app_failure.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/mood/application/mood_controller.dart';
import 'package:moodscape/features/mood/domain/mood.dart';
import 'package:moodscape/features/recommendations/application/recommendations_controller.dart';
import 'package:moodscape/features/recommendations/data/track_source.dart';
import 'package:moodscape/features/recommendations/domain/match_scorer.dart';
import 'package:moodscape/features/recommendations/domain/track.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Source implements TrackSource {
  _Source({required this.isDemo, this.error, this.tracks = const []});

  @override
  final bool isDemo;
  final AppFailure? error;
  final List<Track> tracks;

  @override
  String get label => isDemo ? 'Demo' : 'Spotify search';

  @override
  String? get notice => isDemo ? null : 'estimated';

  @override
  Future<List<Track>> candidates(MatchContext ctx) async {
    final e = error;
    if (e != null) throw e;
    return tracks;
  }
}

const _demoTrack = Track(
  id: 'demo',
  title: 'Demo song',
  artist: 'a',
  provider: MusicProvider.demo,
  valence: 65,
  energy: 25,
);

Future<ProviderContainer> _container(TrackSource primary) async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      trackSourceProvider.overrideWithValue(primary),
      demoTrackSourceProvider.overrideWithValue(
        _Source(isDemo: true, tracks: const [_demoTrack]),
      ),
    ],
  );
  addTearDown(c.dispose);
  c.read(moodControllerProvider.notifier).toggle(Mood.calm);
  return c;
}

void main() {
  test(
    'a failing connected service falls back to the demo catalogue',
    () async {
      final c = await _container(
        _Source(isDemo: false, error: const NetworkFailure('Spotify is down.')),
      );

      final recs = await c.read(recommendationsProvider.future);

      expect(recs.isDemo, isTrue);
      expect(recs.matches.single.track.id, 'demo');
      expect(recs.notice, contains('Spotify is down.'));
      expect(recs.notice, contains('demo catalogue'));
    },
  );

  test('a working service passes its notice through', () async {
    final c = await _container(
      _Source(
        isDemo: false,
        tracks: const [
          Track(
            id: 's1',
            title: 'Spotify song',
            artist: 'a',
            provider: MusicProvider.spotify,
          ),
        ],
      ),
    );

    final recs = await c.read(recommendationsProvider.future);

    expect(recs.isDemo, isFalse);
    expect(recs.notice, 'estimated');
    expect(recs.matches.single.track.id, 's1');
  });

  test('a failing demo catalogue is reported, not hidden', () async {
    final c = await _container(
      _Source(isDemo: true, error: const InvalidResponseFailure()),
    );

    await expectLater(
      c.read(recommendationsProvider.future),
      throwsA(isA<InvalidResponseFailure>()),
    );
  });
}
