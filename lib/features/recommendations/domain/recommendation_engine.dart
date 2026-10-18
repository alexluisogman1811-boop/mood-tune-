import '../../preferences/domain/music_preferences.dart';
import 'match_scorer.dart';
import 'track.dart';

/// Turns candidates into an ordered playlist.
class RecommendationEngine {
  const RecommendationEngine({this.scorer = const MatchScorer()});

  final MatchScorer scorer;

  /// Drops explicit tracks if disallowed (unknown explicitness is kept),
  /// removes duplicates and [exclude]d ids, scores, and returns the best
  /// [limit] by score (ties broken by title for stable output).
  List<TrackMatch> rank(
    Iterable<Track> candidates,
    MatchContext ctx, {
    required int limit,
    Set<String> exclude = const {},
  }) {
    final seen = <String>{};
    final eligible = [
      for (final t in candidates)
        if (!exclude.contains(t.id) &&
            seen.add(t.id) &&
            (ctx.preferences.allowExplicit || t.isExplicit != true))
          t,
    ];
    final scored = [for (final t in eligible) scorer.score(t, ctx)]
      ..sort(compare);
    return scored.take(limit).toList(growable: false);
  }

  /// Playlist order: highest score first, ties broken by title so the
  /// output is stable.
  static int compare(TrackMatch a, TrackMatch b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0
        ? byScore
        : a.track.title.toLowerCase().compareTo(b.track.title.toLowerCase());
  }

  /// A fresh batch that avoids [shown] where possible, topped up with the
  /// best of the rest when the catalogue runs short. [exclude]d ids (e.g.
  /// disliked songs) are never used, not even to top up.
  List<TrackMatch> regenerate(
    Iterable<Track> candidates,
    MatchContext ctx, {
    required int limit,
    required Set<String> shown,
    Set<String> exclude = const {},
  }) {
    final fresh = rank(
      candidates,
      ctx,
      limit: limit,
      exclude: {...shown, ...exclude},
    );
    if (fresh.length >= limit) return fresh;
    final freshIds = {for (final m in fresh) m.track.id};
    final topUp = rank(
      candidates,
      ctx,
      limit: limit,
      exclude: {...freshIds, ...exclude},
    );
    return [...fresh, ...topUp.take(limit - fresh.length)];
  }
}

enum QuickFilter {
  bestMatch('Best match'),
  relaxing('Relaxing'),
  energetic('Energetic'),
  recent('Recently released');

  const QuickFilter(this.label);
  final String label;
}

class ResultFilter {
  const ResultFilter({
    this.quick = QuickFilter.bestMatch,
    this.genre,
    this.language,
  });

  final QuickFilter quick;
  final Genre? genre;
  final MusicLanguage? language;

  static const relaxingMaxEnergy = 45;
  static const energeticMinEnergy = 65;
  static const recentYears = 2;

  ResultFilter copyWith({
    QuickFilter? quick,
    Genre? Function()? genre,
    MusicLanguage? Function()? language,
  }) => ResultFilter(
    quick: quick ?? this.quick,
    genre: genre != null ? genre() : this.genre,
    language: language != null ? language() : this.language,
  );

  /// Tracks with unknown data are excluded by a filter that needs that data,
  /// rather than guessed into it.
  List<TrackMatch> apply(List<TrackMatch> matches, {required int currentYear}) {
    bool keep(TrackMatch m) {
      final t = m.track;
      final quickOk = switch (quick) {
        QuickFilter.bestMatch => true,
        QuickFilter.relaxing =>
          t.energy != null && t.energy! <= relaxingMaxEnergy,
        QuickFilter.energetic =>
          t.energy != null && t.energy! >= energeticMinEnergy,
        QuickFilter.recent => isRecent(t, currentYear),
      };
      return quickOk &&
          (genre == null || t.genres.contains(genre)) &&
          (language == null || t.language == language);
    }

    return matches.where(keep).toList(growable: false);
  }

  static bool isRecent(Track t, int currentYear) =>
      t.releaseYear != null && currentYear - t.releaseYear! <= recentYears;
}
