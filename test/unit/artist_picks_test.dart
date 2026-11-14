import 'package:flutter_test/flutter_test.dart';
import 'package:moodscape/features/mood/domain/mood.dart';
import 'package:moodscape/features/preferences/application/artist_catalog.dart';
import 'package:moodscape/features/preferences/domain/music_preferences.dart';
import 'package:moodscape/features/recommendations/domain/match_scorer.dart';
import 'package:moodscape/features/recommendations/domain/recommendation_engine.dart';
import 'package:moodscape/features/recommendations/domain/track.dart';

Track _t(String id, String artist) => Track(
  id: id,
  title: id,
  artist: artist,
  provider: MusicProvider.demo,
  valence: 50,
  energy: 50,
);

MatchContext _ctx(MusicPreferences p) => MatchContext(
  mood: const MoodInput(moods: {Mood.calm}),
  preferences: p,
);

void main() {
  group('picking a band', () {
    test('a name matches whatever its case and spacing', () {
      const p = MusicPreferences(artists: {'BTS'});
      expect(p.likesArtist('BTS'), isTrue);
      expect(p.likesArtist(' bts '), isTrue);
      expect(p.likesArtist('BTS & friends'), isFalse);
      expect(p.likesArtist(null), isFalse);
      expect(const MusicPreferences().likesArtist('BTS'), isFalse);
    });

    test('picking a band counts as a taste preference', () {
      expect(const MusicPreferences().hasTastePreferences, isFalse);
      expect(
        const MusicPreferences(artists: {'BTS'}).hasTastePreferences,
        isTrue,
      );
    });

    test('picks survive saving and loading, and are capped', () {
      const p = MusicPreferences(
        artists: {'BTS', 'Bodyslam'},
        artistsOnly: true,
      );
      final back = MusicPreferences.fromJson(p.toJson());
      expect(back.artists, {'BTS', 'Bodyslam'});
      expect(back.artistsOnly, isTrue);

      final tooMany = MusicPreferences.fromJson({
        'artists': [for (var i = 0; i < 50; i++) 'Band $i', '', 7],
      });
      expect(tooMany.artists.length, MusicPreferences.maxArtists);
      expect(tooMany.artistsOnly, isFalse);
    });
  });

  group('how picks change the playlist', () {
    const engine = RecommendationEngine();
    final candidates = [_t('mine', 'BTS'), _t('other', 'Someone Else')];

    test('"only these bands" leaves out everyone else', () {
      final out = engine.rank(
        candidates,
        _ctx(const MusicPreferences(artists: {'bts'}, artistsOnly: true)),
        limit: 10,
      );
      expect(out.map((m) => m.track.id), ['mine']);
    });

    test('preferring them keeps the others but puts the band first', () {
      final out = engine.rank(
        candidates,
        _ctx(const MusicPreferences(artists: {'BTS'})),
        limit: 10,
      );
      expect(out.map((m) => m.track.id), ['mine', 'other']);
      expect(out.first.score, greaterThan(out.last.score));
    });

    test('with no picks, nothing is filtered out', () {
      final out = engine.rank(
        candidates,
        _ctx(const MusicPreferences()),
        limit: 10,
      );
      expect(out.length, 2);
    });

    test('the reason names the band', () {
      final match = const MatchScorer().score(
        _t('mine', 'BTS'),
        _ctx(const MusicPreferences(artists: {'BTS'})),
      );
      expect(match.explanationIn('en'), contains('BTS'));
      expect(match.explanationIn('th'), contains('BTS'));
    });
  });

  group('finding a band', () {
    const all = [
      CatalogArtist(name: 'BTS', songs: 66, language: MusicLanguage.korean),
      CatalogArtist(name: 'Bodyslam', songs: 14, language: MusicLanguage.thai),
      CatalogArtist(name: 'Big Bang', songs: 9, language: MusicLanguage.korean),
      CatalogArtist(name: 'Sofiane Pamart', songs: 63),
    ];

    test('typing searches every name, best start first', () {
      final out = suggestArtists(all, query: 'b', picked: const {});
      expect(out.map((a) => a.name), ['BTS', 'Bodyslam', 'Big Bang']);
    });

    test('search ignores case and finds names inside', () {
      expect(
        suggestArtists(all, query: 'PAMART', picked: const {}).single.name,
        'Sofiane Pamart',
      );
    });

    test('bands already picked are not offered again', () {
      final out = suggestArtists(all, query: 'b', picked: const {'bts'});
      expect(out.map((a) => a.name), isNot(contains('BTS')));
    });

    test('with no typing it suggests the chosen languages', () {
      final out = suggestArtists(
        all,
        query: '',
        picked: const {},
        languages: {MusicLanguage.thai},
      );
      expect(out.map((a) => a.name), ['Bodyslam']);
    });

    test('with no typing and no languages it suggests the best known', () {
      final out = suggestArtists(all, query: '', picked: const {}, limit: 2);
      expect(out.map((a) => a.name), ['BTS', 'Bodyslam']);
    });

    test('an unknown name finds nothing', () {
      expect(suggestArtists(all, query: 'zzz', picked: const {}), isEmpty);
    });
  });

  group('the band index file', () {
    test('reads names, counts and language', () {
      final out = parseArtists(
        '{"artists":[{"n":"BTS","c":66,"l":"korean"},{"n":"Pamart","c":63}]}',
      );
      expect(out.first.name, 'BTS');
      expect(out.first.songs, 66);
      expect(out.first.language, MusicLanguage.korean);
      expect(out.last.language, isNull);
    });

    test('skips broken entries instead of losing the list', () {
      final out = parseArtists(
        '{"artists":[{"n":""},{"c":5},"nope",{"n":"Ok","c":2}]}',
      );
      expect(out.map((a) => a.name), ['Ok']);
      expect(parseArtists('[]'), isEmpty);
    });
  });
}
