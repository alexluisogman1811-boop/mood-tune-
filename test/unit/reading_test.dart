import 'package:flutter_test/flutter_test.dart';
import 'package:moodscape/features/mood/domain/mood.dart';
import 'package:moodscape/features/preferences/domain/music_preferences.dart';
import 'package:moodscape/features/reading/domain/reading.dart';
import 'package:moodscape/features/recommendations/domain/match_scorer.dart';
import 'package:moodscape/features/recommendations/domain/track.dart';

Track _track(String id, {required int energy, bool? instrumental}) => Track(
  id: id,
  title: id,
  artist: 'a',
  provider: MusicProvider.demo,
  valence: 60,
  energy: energy,
  isInstrumental: instrumental,
);

MatchContext _ctx({
  ReadingKind? reading,
  MusicPreferences preferences = const MusicPreferences(),
}) => MatchContext(
  mood: const MoodInput(moods: {Mood.calm}),
  preferences: preferences,
  reading: reading,
);

const _scorer = MatchScorer();

void main() {
  group('reading', () {
    test('every kind has a sensible energy target', () {
      for (final k in ReadingKind.values) {
        expect(k.targetEnergy, inInclusiveRange(0, 100), reason: k.name);
      }
    });

    test('without reading, scores are unchanged', () {
      final t = _track('t', energy: 20, instrumental: true);
      expect(MatchScorer.energyMatch(t, const MusicPreferences()), isNull);
      expect(MatchScorer.preferenceMatch(t, const MusicPreferences()), isNull);
    });

    test('reading sets the energy target when the user set none', () {
      final t = _track('t', energy: 15);
      expect(
        MatchScorer.energyMatch(
          t,
          const MusicPreferences(),
          ReadingKind.poetry,
        ),
        100,
      );
    });

    test("the user's own energy choice wins over reading", () {
      final t = _track('t', energy: 80);
      expect(
        MatchScorer.energyMatch(
          t,
          const MusicPreferences(energy: EnergyPreference.energetic),
          ReadingKind.poetry,
        ),
        100,
      );
    });

    test('studying favours songs without lyrics', () {
      final instrumental = _track('i', energy: 25, instrumental: true);
      final vocal = _track('v', energy: 25, instrumental: false);
      final ctx = _ctx(reading: ReadingKind.study);
      expect(
        _scorer.score(instrumental, ctx).score,
        greaterThan(_scorer.score(vocal, ctx).score),
      );
    });

    test('comics do not penalise lyrics', () {
      final vocal = _track('v', energy: 55, instrumental: false);
      expect(
        MatchScorer.preferenceMatch(
          vocal,
          const MusicPreferences(),
          ReadingKind.comics,
        ),
        isNull,
      );
    });

    test('a chosen vocal preference is not overridden by reading', () {
      final vocal = _track('v', energy: 30, instrumental: false);
      expect(
        MatchScorer.preferenceMatch(
          vocal,
          const MusicPreferences(vocal: VocalPreference.vocal),
          ReadingKind.study,
        ),
        100,
      );
    });

    test('the explanation mentions the reading', () {
      final m = _scorer.score(
        _track('t', energy: 30, instrumental: true),
        _ctx(reading: ReadingKind.story),
      );
      expect(m.explanation, contains('good for reading a story'));
      expect(m.explanationIn('th'), contains('เหมาะกับการอ่านนิยาย'));
    });
  });

  group('Thai explanations', () {
    test('word moods in Thai', () {
      final m = _scorer.score(
        _track('t', energy: 25, instrumental: true),
        _ctx(),
      );
      expect(m.explanation, startsWith('Fits your calm mood'));
      expect(m.explanationIn('th'), startsWith('เข้ากับอารมณ์สงบของคุณ'));
    });

    test('weak matches are explained in Thai too', () {
      expect(
        MatchScorer.describe(const [], 'th'),
        'เข้ากันได้น้อยกว่า เพราะต่างจากบางอย่างที่คุณบอกไว้',
      );
    });
  });
}
