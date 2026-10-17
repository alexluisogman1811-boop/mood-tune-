import '../../../services/image_analysis/scene_features.dart';
import '../../mood/domain/mood.dart';
import '../../preferences/domain/music_preferences.dart';
import 'match_scorer.dart';

/// Matching features attached to tracks found by a given search. Music
/// services no longer expose audio features to new apps, so these are
/// estimates derived from the mood and scene words that produced the search.
class EstimatedFeatures {
  const EstimatedFeatures({
    this.valence,
    this.energy,
    this.atmosphere,
    this.cues,
    this.genre,
  });

  final int? valence;
  final int? energy;
  final Set<SceneAtmosphere>? atmosphere;
  final Set<EnvironmentalCue>? cues;
  final Genre? genre;
}

class SearchQuery {
  const SearchQuery(this.text, this.features);
  final String text;
  final EstimatedFeatures features;
}

/// How a service expresses "in this genre" inside a search term.
typedef GenreTerm = String Function(Genre genre);

/// Turns mood, scene and genre preferences into a handful of catalogue
/// search queries. The user's free-text description is never sent.
abstract final class SearchQueryPlanner {
  static const maxQueries = 6;

  static const moodWords = {
    Mood.happy: 'happy',
    Mood.calm: 'calm',
    Mood.sad: 'sad',
    Mood.stressed: 'tense',
    Mood.tired: 'mellow',
    Mood.motivated: 'motivation',
    Mood.romantic: 'romantic',
    Mood.nostalgic: 'nostalgic',
    Mood.lonely: 'lonely',
    Mood.excited: 'party',
    Mood.focused: 'focus',
  };

  static const atmosphereWords = {
    SceneAtmosphere.cozy: 'cozy',
    SceneAtmosphere.dreamy: 'dreamy',
    SceneAtmosphere.peaceful: 'peaceful',
    SceneAtmosphere.dramatic: 'cinematic',
    SceneAtmosphere.energetic: 'upbeat',
    SceneAtmosphere.nostalgic: 'retro',
  };

  static const cueWords = {
    EnvironmentalCue.rain: 'rainy',
    EnvironmentalCue.sunshine: 'sunny',
    EnvironmentalCue.fog: 'misty',
    EnvironmentalCue.cloudy: 'cloudy',
    EnvironmentalCue.snow: 'winter',
    EnvironmentalCue.night: 'night',
  };

  static List<SearchQuery> plan(
    MatchContext ctx, {
    required GenreTerm genreTerm,
  }) {
    final targets = MatchScorer.moodTargets(ctx.mood).entries.take(3).toList();
    final scene = ctx.scene;

    // At most one scene word: the first atmosphere, else the first cue.
    String? sceneWord;
    Set<SceneAtmosphere>? sceneAtm;
    Set<EnvironmentalCue>? sceneCues;
    if (scene != null) {
      if (scene.atmosphere.isNotEmpty) {
        final a = scene.atmosphere.first;
        sceneWord = atmosphereWords[a];
        sceneAtm = {a};
      } else if (scene.cues.isNotEmpty) {
        final c = scene.cues.first;
        sceneWord = cueWords[c];
        sceneCues = {c};
      }
    }
    final genres = [
      for (final g in Genre.values)
        if (ctx.preferences.genres.contains(g)) g,
    ].take(2).toList();

    final out = <SearchQuery>[];
    void add(String text, EstimatedFeatures f) {
      if (out.length < maxQueries && !out.any((q) => q.text == text)) {
        out.add(SearchQuery(text, f));
      }
    }

    // Round-robin across moods, tier by tier (scene → genres → plain), so
    // every selected mood is represented before any mood gets a second query.
    final tiers = <List<SearchQuery>>[
      for (final MapEntry(key: mood, value: (v, e)) in targets)
        [
          if (sceneWord != null)
            SearchQuery(
              '${moodWords[mood]} $sceneWord',
              EstimatedFeatures(
                valence: v.round(),
                energy: e.round(),
                atmosphere: sceneAtm,
                cues: sceneCues,
              ),
            ),
          for (final g in genres)
            SearchQuery(
              '${moodWords[mood]} ${genreTerm(g)}',
              EstimatedFeatures(
                valence: v.round(),
                energy: e.round(),
                genre: g,
              ),
            ),
          SearchQuery(
            moodWords[mood]!,
            EstimatedFeatures(valence: v.round(), energy: e.round()),
          ),
        ],
    ];
    final depth = tiers.fold(0, (m, t) => t.length > m ? t.length : m);
    for (var i = 0; i < depth; i++) {
      for (final perMood in tiers) {
        if (i < perMood.length) add(perMood[i].text, perMood[i].features);
      }
    }

    if (out.isEmpty) {
      // Only "Other" selected: fall back to scene and genres, no mood target.
      if (sceneWord != null) {
        add(
          sceneWord,
          EstimatedFeatures(atmosphere: sceneAtm, cues: sceneCues),
        );
      }
      for (final g in genres) {
        add(genreTerm(g), EstimatedFeatures(genre: g));
      }
      if (out.isEmpty) add('chill', const EstimatedFeatures());
    }
    return out;
  }
}
