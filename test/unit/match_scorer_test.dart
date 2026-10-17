import 'package:flutter_test/flutter_test.dart';
import 'package:moodscape/features/mood/domain/mood.dart';
import 'package:moodscape/features/preferences/domain/music_preferences.dart';
import 'package:moodscape/features/recommendations/domain/match_scorer.dart';
import 'package:moodscape/features/recommendations/domain/track.dart';
import 'package:moodscape/services/image_analysis/scene_features.dart';

Track _track({
  String id = 't',
  int? valence,
  int? energy,
  int? popularity,
  Set<Genre> genres = const {},
  MusicLanguage? language,
  bool? instrumental,
  bool? explicit,
  Set<SceneAtmosphere>? atmosphere,
  Set<EnvironmentalCue>? cues,
}) => Track(
  id: id,
  title: id,
  artist: 'a',
  provider: MusicProvider.demo,
  valence: valence,
  energy: energy,
  popularity: popularity,
  genres: genres,
  language: language,
  isInstrumental: instrumental,
  isExplicit: explicit,
  atmosphere: atmosphere,
  cues: cues,
);

SceneFeatures _scene({
  int energy = 30,
  double confidence = 1,
  Set<SceneAtmosphere> atmosphere = const {SceneAtmosphere.cozy},
  Set<EnvironmentalCue> cues = const {EnvironmentalCue.rain},
}) => SceneFeatures(
  setting: SceneSetting.indoor,
  lighting: SceneLighting.warm,
  atmosphere: atmosphere,
  cues: cues,
  energy: energy,
  confidence: confidence,
  source: AnalysisSource.mock,
);

MatchContext _ctx({
  Set<Mood> moods = const {Mood.calm},
  int? intensity,
  MusicPreferences preferences = const MusicPreferences(),
  SceneFeatures? scene,
}) => MatchContext(
  mood: MoodInput(moods: moods, intensity: intensity),
  preferences: preferences,
  scene: scene,
);

const _scorer = MatchScorer();

void main() {
  group('weights', () {
    test('default weights are 40/25/20/15', () {
      const w = MatchWeights();
      expect(
        [w.mood, w.atmosphere, w.preference, w.energy],
        [0.40, 0.25, 0.20, 0.15],
      );
    });

    test('all four components use the documented formula', () {
      final t = _track(
        valence: 65,
        energy: 25,
        genres: {Genre.jazz},
        atmosphere: {SceneAtmosphere.cozy},
        cues: {EnvironmentalCue.rain},
      );
      final ctx = _ctx(
        preferences: const MusicPreferences(
          genres: {Genre.jazz},
          energy: EnergyPreference.relaxing,
        ),
        scene: _scene(energy: 25),
      );
      final m = _scorer.score(t, ctx);
      final c = m.components;
      final expected =
          c[MatchComponent.mood]! * 0.40 +
          c[MatchComponent.atmosphere]! * 0.25 +
          c[MatchComponent.preference]! * 0.20 +
          c[MatchComponent.energy]! * 0.15;
      expect(m.score, expected.round());
      expect(m.weights.values.reduce((a, b) => a + b), closeTo(1, 1e-9));
    });

    test('custom weights are respected', () {
      const scorer = MatchScorer(
        weights: MatchWeights(mood: 1, atmosphere: 0, preference: 0, energy: 0),
      );
      final t = _track(valence: 65, energy: 25);
      final m = scorer.score(t, _ctx(scene: _scene(energy: 100)));
      expect(m.score, m.components[MatchComponent.mood]!.round());
    });

    test('all-zero weights share equally instead of dividing by zero', () {
      final w = MatchScorer.normalizedWeights([
        MatchComponent.mood,
        MatchComponent.energy,
      ], const MatchWeights(mood: 0, atmosphere: 0, preference: 0, energy: 0));
      expect(w.values, [0.5, 0.5]);
    });
  });

  group('missing data redistributes weight', () {
    test('no scene, no preferences: mood carries all the weight', () {
      final m = _scorer.score(_track(valence: 65, energy: 25), _ctx());
      expect(m.components.keys, [MatchComponent.mood]);
      expect(m.weights[MatchComponent.mood], 1.0);
      expect(m.score, m.components[MatchComponent.mood]!.round());
    });

    test('mood + scene split 40:25 → 61.5% / 38.5%', () {
      final m = _scorer.score(
        _track(valence: 65, energy: 25, atmosphere: {}, cues: {}),
        _ctx(scene: _scene()),
      );
      expect(m.weights[MatchComponent.mood], closeTo(0.40 / 0.65, 1e-9));
      expect(m.weights[MatchComponent.atmosphere], closeTo(0.25 / 0.65, 1e-9));
    });

    test('a missing component is not treated as zero', () {
      final t = _track(valence: 65, energy: 25); // perfect calm match
      final withPrefs = _scorer.score(
        t,
        _ctx(preferences: const MusicPreferences(genres: {Genre.jazz})),
      );
      // Track has no genre data → preference component absent, score stays 100.
      expect(
        withPrefs.components.containsKey(MatchComponent.preference),
        isFalse,
      );
      expect(withPrefs.score, 100);
    });

    test('track with no features at all gets the neutral score', () {
      final m = _scorer.score(_track(), _ctx(moods: {Mood.other}));
      expect(m.components, isEmpty);
      expect(m.weights, isEmpty);
      expect(m.score, MatchScorer.neutralScore);
    });

    test('"Other" alone contributes no mood component', () {
      expect(
        MatchScorer.moodMatch(
          _track(valence: 50, energy: 50),
          const MoodInput(moods: {Mood.other}),
        ),
        isNull,
      );
    });

    test('track with only energy still gets a mood score', () {
      final s = MatchScorer.moodMatch(
        _track(energy: 25),
        const MoodInput(moods: {Mood.calm}),
      );
      expect(s, 100);
    });
  });

  group('mood matching', () {
    test('exact mood point scores 100; opposite corner scores low', () {
      final calm = const MoodInput(moods: {Mood.calm});
      expect(MatchScorer.moodMatch(_track(valence: 65, energy: 25), calm), 100);
      expect(
        MatchScorer.moodMatch(_track(valence: 0, energy: 100), calm)!,
        lessThan(50),
      );
    });

    test('conflicting moods: a song fitting one beats one fitting neither', () {
      const conflicted = MoodInput(moods: {Mood.happy, Mood.sad});
      final happySong = MatchScorer.moodMatch(
        _track(valence: 85, energy: 70),
        conflicted,
      )!;
      final offSong = MatchScorer.moodMatch(
        _track(valence: 50, energy: 100),
        conflicted,
      )!;
      expect(happySong, greaterThan(offSong));
      expect(happySong, inInclusiveRange(0, 100));
    });

    test('intensity pushes the target away from neutral', () {
      final mild = MatchScorer.moodTargets(
        const MoodInput(moods: {Mood.excited}, intensity: 1),
      )[Mood.excited]!;
      final strong = MatchScorer.moodTargets(
        const MoodInput(moods: {Mood.excited}, intensity: 5),
      )[Mood.excited]!;
      expect(strong.$2, greaterThan(mild.$2));
      expect(strong.$2, lessThanOrEqualTo(100)); // clamped
    });
  });

  group('atmosphere matching', () {
    test('full tag overlap and equal energy with full confidence = 100', () {
      final s = MatchScorer.atmosphereMatch(
        _track(
          energy: 30,
          atmosphere: {SceneAtmosphere.cozy},
          cues: {EnvironmentalCue.rain},
        ),
        _scene(),
      );
      expect(s, 100);
    });

    test('low confidence pulls the score toward neutral', () {
      final t = _track(
        energy: 30,
        atmosphere: {SceneAtmosphere.cozy},
        cues: {EnvironmentalCue.rain},
      );
      expect(MatchScorer.atmosphereMatch(t, _scene(confidence: 0.2)), 60);
      expect(MatchScorer.atmosphereMatch(t, _scene(confidence: 0)), 50);
    });

    test('unknown track tags and energy → null', () {
      expect(MatchScorer.atmosphereMatch(_track(), _scene()), isNull);
    });
  });

  group('preference matching', () {
    test('empty preferences → null (skipped screen)', () {
      expect(
        MatchScorer.preferenceMatch(
          _track(genres: {Genre.pop}),
          const MusicPreferences(),
        ),
        isNull,
      );
    });

    test('genre, language, vocal and discovery checks average', () {
      final s = MatchScorer.preferenceMatch(
        _track(
          genres: {Genre.jazz},
          language: MusicLanguage.french,
          instrumental: false,
          popularity: 80,
        ),
        const MusicPreferences(
          genres: {Genre.jazz}, // 100
          languages: {MusicLanguage.english}, // 0
          vocal: VocalPreference.vocal, // 100
          discovery: DiscoveryPreference.discover, // 20
        ),
      );
      expect(s, closeTo((100 + 0 + 100 + 20) / 4, 1e-9));
    });

    test('language is ignored for instrumental tracks', () {
      final s = MatchScorer.preferenceMatch(
        _track(language: MusicLanguage.french, instrumental: true),
        const MusicPreferences(languages: {MusicLanguage.english}),
      );
      expect(s, isNull);
    });
  });

  group('energy matching', () {
    test('needs both a request and track energy', () {
      expect(
        MatchScorer.energyMatch(_track(energy: 50), const MusicPreferences()),
        isNull,
      );
      expect(
        MatchScorer.energyMatch(
          _track(),
          const MusicPreferences(energy: EnergyPreference.energetic),
        ),
        isNull,
      );
    });

    test('boundaries: exact target 100, farthest 20', () {
      const p = MusicPreferences(energy: EnergyPreference.energetic); // 80
      expect(MatchScorer.energyMatch(_track(energy: 80), p), 100);
      expect(MatchScorer.energyMatch(_track(energy: 0), p), 20);
    });
  });

  group('final score bounds', () {
    test('always an int within 0..100 across extreme inputs', () {
      for (final v in [0, 100]) {
        for (final e in [0, 100]) {
          for (final moods in [
            {Mood.happy},
            {Mood.sad, Mood.excited, Mood.tired},
            Mood.values.toSet(),
          ]) {
            final m = _scorer.score(
              _track(
                valence: v,
                energy: e,
                popularity: v,
                genres: {Genre.rock},
                atmosphere: {},
                cues: {},
              ),
              _ctx(
                moods: moods,
                intensity: 5,
                scene: _scene(energy: 100 - e),
                preferences: const MusicPreferences(
                  genres: {Genre.jazz},
                  discovery: DiscoveryPreference.familiar,
                  energy: EnergyPreference.relaxing,
                ),
              ),
            );
            expect(m.score, inInclusiveRange(0, 100));
          }
        }
      }
    });
  });

  group('explanations', () {
    test('names only the moods the song fits', () {
      final m = _scorer.score(
        _track(valence: 85, energy: 70),
        _ctx(moods: {Mood.happy, Mood.sad}),
      );
      expect(m.explanation, contains('happy'));
      expect(m.explanation, isNot(contains('sad')));
    });

    test('mentions shared scene tags and liked genres', () {
      final m = _scorer.score(
        _track(
          valence: 65,
          energy: 30,
          genres: {Genre.jazz},
          atmosphere: {SceneAtmosphere.cozy},
          cues: {EnvironmentalCue.rain},
        ),
        _ctx(
          scene: _scene(),
          preferences: const MusicPreferences(genres: {Genre.jazz}),
        ),
      );
      expect(m.explanation, contains('cozy'));
      expect(m.explanation, contains('Jazz'));
      expect(m.explanation, endsWith('.'));
    });

    test('weak matches say so', () {
      final m = _scorer.score(
        _track(valence: 0, energy: 100),
        _ctx(moods: {Mood.calm}),
      );
      expect(m.explanation, startsWith('A looser match'));
    });
  });
}
