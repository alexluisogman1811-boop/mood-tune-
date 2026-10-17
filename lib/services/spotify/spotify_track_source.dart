import '../../features/preferences/domain/music_preferences.dart';
import '../../features/recommendations/data/track_source.dart';
import '../../features/recommendations/domain/match_scorer.dart';
import '../../features/recommendations/domain/search_query_planner.dart';
import '../../features/recommendations/domain/track.dart';
import 'spotify_api_client.dart';
import 'spotify_track_mapper.dart';

/// Candidates from Spotify search. Spotify no longer offers recommendations
/// or audio features to new apps, so each track carries features estimated
/// from the search that found it.
class SpotifyTrackSource implements TrackSource {
  const SpotifyTrackSource(this._client, {this.pagesPerQuery = 2});

  final SpotifyApiClient _client;
  final int pagesPerQuery;

  /// Spotify's `genre:` filter names.
  static const genreFilter = {
    Genre.pop: 'pop',
    Genre.rock: 'rock',
    Genre.hipHop: 'hip-hop',
    Genre.rnb: 'r-n-b',
    Genre.soul: 'soul',
    Genre.electronic: 'electronic',
    Genre.jazz: 'jazz',
    Genre.classical: 'classical',
    Genre.indie: 'indie',
    Genre.folk: 'folk',
    Genre.lofi: 'lo-fi',
    Genre.ambient: 'ambient',
    Genre.latin: 'latin',
    Genre.kpop: 'k-pop',
    Genre.soundtrack: 'soundtrack',
    Genre.country: 'country',
  };

  static String genreTerm(Genre g) => 'genre:"${genreFilter[g]}"';

  @override
  String get label => 'Spotify search';

  @override
  bool get isDemo => false;

  @override
  String? get notice =>
      'Spotify does not share audio features with new apps, so mood fit is '
      'estimated from the search words that found each song.';

  @override
  Future<List<Track>> candidates(MatchContext ctx) async {
    final queries = SearchQueryPlanner.plan(ctx, genreTerm: genreTerm);
    final pages = await Future.wait([
      for (final q in queries)
        Future.wait([
          for (var p = 0; p < pagesPerQuery; p++)
            _client.searchTracks(
              q.text,
              offset: p * SpotifyApiClient.maxSearchLimit,
            ),
        ]),
    ]);

    // Earlier queries have priority when the same song is found twice.
    final seen = <String>{};
    return [
      for (var i = 0; i < queries.length; i++)
        for (final page in pages[i])
          for (final raw in page)
            if (SpotifyTrackMapper.fromJson(raw, queries[i].features)
                case final t? when seen.add(t.id))
              t,
    ];
  }
}
