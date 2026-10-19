import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodscape/features/mood/domain/mood.dart';
import 'package:moodscape/features/preferences/domain/music_preferences.dart';
import 'package:moodscape/features/recommendations/data/demo_track_source.dart';
import 'package:moodscape/features/recommendations/domain/match_scorer.dart';
import 'package:moodscape/features/recommendations/domain/recommendation_engine.dart';
import 'package:moodscape/features/recommendations/domain/track.dart';

Track _t(
  String id, {
  int? energy,
  bool? explicit,
  int? year,
  Set<Genre> genres = const {},
  MusicLanguage? language,
  int valence = 50,
}) => Track(
  id: id,
  title: id,
  artist: 'a',
  provider: MusicProvider.demo,
  valence: valence,
  energy: energy,
  isExplicit: explicit,
  releaseYear: year,
  genres: genres,
  language: language,
);

const _engine = RecommendationEngine();

MatchContext _ctx({bool allowExplicit = true}) => MatchContext(
  mood: const MoodInput(moods: {Mood.calm}),
  preferences: MusicPreferences(allowExplicit: allowExplicit),
);

void main() {
  group('chosen languages', () {
    MatchContext withLanguages(Set<MusicLanguage> languages) => MatchContext(
      mood: const MoodInput(moods: {Mood.calm}),
      preferences: MusicPreferences(languages: languages),
    );
    final candidates = [
      _t('ko', language: MusicLanguage.korean),
      _t('en', language: MusicLanguage.english),
      Track(
        id: 'piano',
        title: 'piano',
        artist: 'a',
        provider: MusicProvider.demo,
        valence: 50,
        isInstrumental: true,
      ),
      _t('unknown'), // e.g. a service that doesn't report language
    ];
    List<String> ids(Set<MusicLanguage> languages) => [
      for (final m in _engine.rank(
        candidates,
        withLanguages(languages),
        limit: 10,
      ))
        m.track.id,
    ];

    test('only songs in the chosen languages (or unknown) remain', () {
      expect(ids({MusicLanguage.korean}), unorderedEquals(['ko', 'unknown']));
    });

    test('no choice keeps every song', () {
      expect(ids({}), hasLength(4));
    });
  });

  group('rank', () {
    test('orders by score, then title; respects limit', () {
      final out = _engine.rank(
        [
          _t('b', valence: 65, energy: 25),
          _t('a', valence: 65, energy: 25),
          _t('far', valence: 0, energy: 100),
        ],
        _ctx(),
        limit: 2,
      );
      expect([for (final m in out) m.track.id], ['a', 'b']);
    });

    test('drops explicit tracks when disallowed but keeps unknown', () {
      final out = _engine.rank(
        [_t('x', explicit: true), _t('clean', explicit: false), _t('unknown')],
        _ctx(allowExplicit: false),
        limit: 10,
      );
      expect({for (final m in out) m.track.id}, {'clean', 'unknown'});
    });

    test('removes duplicate ids', () {
      final out = _engine.rank([_t('a'), _t('a')], _ctx(), limit: 10);
      expect(out, hasLength(1));
    });
  });

  group('regenerate', () {
    final catalog = [for (var i = 0; i < 5; i++) _t('t$i', energy: i * 20)];

    test('avoids songs already shown when enough remain', () {
      final out = _engine.regenerate(
        catalog,
        _ctx(),
        limit: 2,
        shown: {'t0', 't1'},
      );
      expect(out.map((m) => m.track.id), isNot(contains('t0')));
      expect(out, hasLength(2));
    });

    test('tops up from shown songs when the catalogue runs short', () {
      final out = _engine.regenerate(
        catalog,
        _ctx(),
        limit: 4,
        shown: {'t0', 't1', 't2'},
      );
      expect(out, hasLength(4));
      expect(out.map((m) => m.track.id).toSet(), hasLength(4));
    });
  });

  group('filters', () {
    final matches = _engine.rank(
      [
        _t(
          'calm',
          energy: 20,
          genres: {Genre.jazz},
          language: MusicLanguage.english,
        ),
        _t('loud', energy: 90, year: 2025, language: MusicLanguage.spanish),
        _t('mid', energy: 55, year: 2010),
        _t('unknown'),
      ],
      _ctx(),
      limit: 10,
    );
    List<String> ids(ResultFilter f) =>
        [for (final m in f.apply(matches, currentYear: 2026)) m.track.id]
          ..sort();

    test('best match keeps everything', () {
      expect(ids(const ResultFilter()), ['calm', 'loud', 'mid', 'unknown']);
    });

    test('relaxing / energetic exclude unknown energy', () {
      expect(ids(const ResultFilter(quick: QuickFilter.relaxing)), ['calm']);
      expect(ids(const ResultFilter(quick: QuickFilter.energetic)), ['loud']);
    });

    test('recent uses only known release years', () {
      expect(ids(const ResultFilter(quick: QuickFilter.recent)), ['loud']);
    });

    test('genre and language filters combine', () {
      expect(ids(const ResultFilter(genre: Genre.jazz)), ['calm']);
      expect(ids(const ResultFilter(language: MusicLanguage.spanish)), [
        'loud',
      ]);
      expect(
        ids(
          const ResultFilter(
            genre: Genre.jazz,
            language: MusicLanguage.spanish,
          ),
        ),
        isEmpty,
      );
    });
  });

  group('demo catalogue', () {
    final raw = File(DemoTrackSource.assetPath).readAsStringSync();

    test('every entry parses (no silently dropped tracks)', () {
      final tracks = DemoTrackSource.parse(raw);
      final entries = RegExp(r'"id":').allMatches(raw).length;
      expect(tracks, hasLength(entries));
      expect(tracks.length, greaterThanOrEqualTo(150));
    });

    test('every song language has plenty of songs', () {
      final tracks = DemoTrackSource.parse(raw);
      for (final l in MusicLanguage.values) {
        expect(
          tracks.where((t) => t.language == l).length,
          greaterThanOrEqualTo(15),
          reason: l.name,
        );
      }
    });

    test('ids are unique and features are complete', () {
      final tracks = DemoTrackSource.parse(raw);
      expect(tracks.map((t) => t.id).toSet(), hasLength(tracks.length));
      for (final t in tracks) {
        expect(t.valence, isNotNull, reason: t.id);
        expect(t.energy, isNotNull, reason: t.id);
        expect(t.genres, isNotEmpty, reason: t.id);
        expect(
          t.isInstrumental == true || t.language != null,
          isTrue,
          reason: '${t.id} needs a language unless instrumental',
        );
      }
    });

    test('malformed entries are skipped, not fatal', () {
      final tracks = DemoTrackSource.parse(
        '{"tracks": [{"id": "ok", "title": "t", "artist": "a"}, '
        '{"title": "no id"}, {"id": "bad", "title": "t", "artist": "a", '
        '"energy": 400}]}',
      );
      expect(tracks.map((t) => t.id), ['ok']);
    });
  });
}
