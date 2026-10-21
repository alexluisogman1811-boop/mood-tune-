import 'package:flutter_test/flutter_test.dart';
import 'package:moodscape/features/activity/domain/activity.dart';
import 'package:moodscape/features/mood/domain/mood.dart';
import 'package:moodscape/features/preferences/domain/music_preferences.dart';
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
  Activity? activity,
  MusicPreferences preferences = const MusicPreferences(),
}) => MatchContext(
  mood: const MoodInput(moods: {Mood.calm}),
  preferences: preferences,
  activity: activity,
);

const _scorer = MatchScorer();

void main() {
  group('activity', () {
    test('every activity has a sensible energy target', () {
      for (final a in Activity.values) {
        expect(a.targetEnergy, inInclusiveRange(0, 100), reason: a.name);
      }
    });

    test('lively activities aim higher than quiet ones', () {
      expect(
        Activity.exercise.targetEnergy,
        greaterThan(Activity.chilling.targetEnergy),
      );
      expect(
        Activity.party.targetEnergy,
        greaterThan(Activity.sleeping.targetEnergy),
      );
    });

    test('without an activity, scores are unchanged', () {
      final t = _track('t', energy: 20, instrumental: true);
      expect(MatchScorer.energyMatch(t, const MusicPreferences()), isNull);
      expect(MatchScorer.preferenceMatch(t, const MusicPreferences()), isNull);
    });

    test('the activity sets the energy target when the user set none', () {
      expect(
        MatchScorer.energyMatch(
          _track('t', energy: 90),
          const MusicPreferences(),
          Activity.exercise,
        ),
        100,
      );
    });

    test('the gym ranks a high-energy song above a quiet one', () {
      final ctx = _ctx(activity: Activity.exercise);
      expect(
        _scorer
            .score(_track('loud', energy: 90), ctx)
            .components[MatchComponent.energy],
        greaterThan(
          _scorer
              .score(_track('quiet', energy: 15), ctx)
              .components[MatchComponent.energy]!,
        ),
      );
    });

    test("the user's own energy choice wins over the activity", () {
      expect(
        MatchScorer.energyMatch(
          _track('t', energy: 25),
          const MusicPreferences(energy: EnergyPreference.relaxing),
          Activity.exercise,
        ),
        100,
      );
    });

    test('studying favours songs without lyrics', () {
      final instrumental = _track('i', energy: 25, instrumental: true);
      final vocal = _track('v', energy: 25, instrumental: false);
      final ctx = _ctx(activity: Activity.studying);
      expect(
        _scorer.score(instrumental, ctx).score,
        greaterThan(_scorer.score(vocal, ctx).score),
      );
    });

    test('driving does not penalise lyrics', () {
      expect(
        MatchScorer.preferenceMatch(
          _track('v', energy: 65, instrumental: false),
          const MusicPreferences(),
          Activity.driving,
        ),
        isNull,
      );
    });

    test('chosen song languages switch off the no-lyrics preference', () {
      expect(
        MatchScorer.preferenceMatch(
          _track('v', energy: 25, instrumental: false),
          const MusicPreferences(languages: {MusicLanguage.thai}),
          Activity.studying,
        ),
        isNot(30),
      );
    });

    test('the explanation mentions the activity', () {
      final m = _scorer.score(
        _track('t', energy: 85),
        _ctx(activity: Activity.running),
      );
      expect(m.explanation.toLowerCase(), contains('keeps your running pace'));
      expect(m.explanationIn('th'), contains('ช่วยรักษาจังหวะการวิ่ง'));
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
