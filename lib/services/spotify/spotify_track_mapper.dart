import '../../features/recommendations/domain/track.dart';
import '../../features/recommendations/domain/search_query_planner.dart';

abstract final class SpotifyTrackMapper {
  /// Converts a Spotify track object; returns null when required fields are
  /// missing or the item is not playable as a track.
  static Track? fromJson(Map<String, Object?> json, EstimatedFeatures f) {
    final id = json['id'];
    final name = json['name'];
    final uri = json['uri'];
    if (id is! String || name is! String || uri is! String) return null;
    if (id.isEmpty || name.isEmpty || !uri.startsWith('spotify:track:')) {
      return null;
    }

    final artists = json['artists'];
    final artistNames = [
      if (artists is List)
        for (final a in artists)
          if (a is Map && a['name'] is String) a['name'] as String,
    ];
    if (artistNames.isEmpty) return null;

    final album = json['album'] is Map ? json['album'] as Map : const {};
    final ext = json['external_urls'] is Map
        ? json['external_urls'] as Map
        : const {};
    final explicit = json['explicit'];

    return Track(
      id: id,
      title: name,
      artist: artistNames.join(', '),
      provider: MusicProvider.spotify,
      providerUri: uri,
      album: album['name'] is String ? album['name'] as String : null,
      artworkUrl: _bestImage(album['images']),
      previewUrl: _https(json['preview_url']),
      externalUrl: _https(ext['spotify']),
      releaseYear: _year(album['release_date']),
      isExplicit: explicit is bool ? explicit : null,
      genres: {?f.genre},
      valence: f.valence,
      energy: f.energy,
      atmosphere: f.atmosphere,
      cues: f.cues,
    );
  }

  /// Image closest to 300px wide, for list and detail views.
  static Uri? _bestImage(Object? images) {
    if (images is! List || images.isEmpty) return null;
    Map? best;
    var bestDiff = 1 << 30;
    for (final img in images) {
      if (img is! Map || img['url'] is! String) continue;
      final w = img['width'] is int ? img['width'] as int : 300;
      final diff = (w - 300).abs();
      if (diff < bestDiff) {
        best = img;
        bestDiff = diff;
      }
    }
    return best == null ? null : _https(best['url']);
  }

  static Uri? _https(Object? raw) {
    if (raw is! String) return null;
    final uri = Uri.tryParse(raw);
    return uri != null && uri.scheme == 'https' ? uri : null;
  }

  static int? _year(Object? date) {
    if (date is! String || date.length < 4) return null;
    final y = int.tryParse(date.substring(0, 4));
    return y != null && y > 1800 && y < 2200 ? y : null;
  }
}
