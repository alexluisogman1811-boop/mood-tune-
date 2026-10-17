import '../../core/errors/app_failure.dart';
import '../../features/preferences/domain/music_preferences.dart';
import '../../features/recommendations/data/track_source.dart';
import '../../features/recommendations/domain/match_scorer.dart';
import '../../features/recommendations/domain/search_query_planner.dart';
import '../../features/recommendations/domain/track.dart';
import 'apple_music_api_client.dart';
import 'apple_music_track_mapper.dart';

/// Candidates from Apple Music catalogue search. Genres, release dates,
/// explicit ratings and previews are real metadata; mood fit is estimated
/// from the search words because Apple exposes no audio features.
class AppleMusicTrackSource implements TrackSource {
  const AppleMusicTrackSource(
    this._client, {
    required this.fallbackStorefront,
    this.useUserStorefront = false,
  });

  final AppleMusicApiClient _client;

  /// Used when the user's own storefront is unknown (e.g. device region).
  final String fallbackStorefront;

  /// Ask Apple for the signed-in user's storefront first.
  final bool useUserStorefront;

  static String genreTerm(Genre g) => g.label.toLowerCase();

  @override
  String get label => 'Apple Music catalogue';

  @override
  bool get isDemo => false;

  @override
  String? get notice =>
      'Apple Music does not share audio features, so mood fit is estimated '
      'from the search words that found each song.';

  @override
  Future<List<Track>> candidates(MatchContext ctx) async {
    var storefront = AppleMusicApiClient.isValidStorefront(fallbackStorefront)
        ? fallbackStorefront
        : 'us';
    if (useUserStorefront) {
      try {
        storefront = await _client.userStorefront() ?? storefront;
      } on AppFailure {
        // Fall back to the device region.
      }
    }

    final queries = SearchQueryPlanner.plan(ctx, genreTerm: genreTerm);
    final pages = await Future.wait([
      for (final q in queries)
        _client.searchSongs(q.text, storefront: storefront),
    ]);

    final seen = <String>{};
    return [
      for (var i = 0; i < queries.length; i++)
        for (final raw in pages[i])
          if (AppleMusicTrackMapper.fromJson(raw, queries[i].features)
              case final t? when seen.add(t.id))
            t,
    ];
  }
}
