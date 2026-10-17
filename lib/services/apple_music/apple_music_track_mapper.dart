import '../../features/preferences/domain/music_preferences.dart';
import '../../features/recommendations/domain/search_query_planner.dart';
import '../../features/recommendations/domain/track.dart';

abstract final class AppleMusicTrackMapper {
  static const artworkSize = 300;

  /// Maps Apple's genre names (e.g. "Hip-Hop/Rap", "R&B/Soul") to ours.
  static Set<Genre> genresFrom(Object? names) {
    if (names is! List) return {};
    final out = <Genre>{};
    for (final raw in names.whereType<String>()) {
      final n = raw.toLowerCase();
      if (n.contains('k-pop')) {
        out.add(Genre.kpop);
      } else if (n.contains('pop')) {
        out.add(Genre.pop);
      }
      if (n.contains('rock') || n.contains('metal')) out.add(Genre.rock);
      if (n.contains('hip-hop') || n.contains('rap')) out.add(Genre.hipHop);
      if (n.contains('r&b')) out.add(Genre.rnb);
      if (n.contains('soul') || n.contains('funk')) out.add(Genre.soul);
      if (n.contains('electronic') || n.contains('dance')) {
        out.add(Genre.electronic);
      }
      if (n.contains('jazz')) out.add(Genre.jazz);
      if (n.contains('classical')) out.add(Genre.classical);
      if (n.contains('alternative') || n.contains('indie')) {
        out.add(Genre.indie);
      }
      if (n.contains('folk') || n.contains('singer/songwriter')) {
        out.add(Genre.folk);
      }
      if (n.contains('lo-fi') || n.contains('lofi')) out.add(Genre.lofi);
      if (n.contains('ambient') || n.contains('new age')) {
        out.add(Genre.ambient);
      }
      if (n.contains('latin') ||
          n.contains('urbano') ||
          n.contains('reggaeton')) {
        out.add(Genre.latin);
      }
      if (n.contains('soundtrack')) out.add(Genre.soundtrack);
      if (n.contains('country')) out.add(Genre.country);
    }
    return out;
  }

  /// Converts an Apple Music song resource; null when required data is
  /// missing.
  static Track? fromJson(Map<String, Object?> json, EstimatedFeatures f) {
    final id = json['id'];
    final attrs = json['attributes'];
    if (id is! String || id.isEmpty || json['type'] != 'songs') return null;
    if (attrs is! Map) return null;
    final name = attrs['name'], artist = attrs['artistName'];
    if (name is! String || name.isEmpty) return null;
    if (artist is! String || artist.isEmpty) return null;

    final rating = attrs['contentRating'];
    final previews = attrs['previews'];
    final firstPreview =
        previews is List && previews.isNotEmpty && previews.first is Map
        ? (previews.first as Map)['url']
        : null;

    return Track(
      id: id,
      title: name,
      artist: artist,
      provider: MusicProvider.appleMusic,
      providerUri: id,
      album: attrs['albumName'] is String ? attrs['albumName'] as String : null,
      artworkUrl: _artwork(attrs['artwork']),
      previewUrl: _https(firstPreview),
      externalUrl: _https(attrs['url']),
      releaseYear: _year(attrs['releaseDate']),
      isExplicit: switch (rating) {
        'explicit' => true,
        'clean' => false,
        _ => null,
      },
      genres: {...genresFrom(attrs['genreNames']), ?f.genre},
      valence: f.valence,
      energy: f.energy,
      atmosphere: f.atmosphere,
      cues: f.cues,
    );
  }

  static Uri? _artwork(Object? artwork) {
    if (artwork is! Map || artwork['url'] is! String) return null;
    final template = artwork['url'] as String;
    return _https(
      template
          .replaceAll('{w}', '$artworkSize')
          .replaceAll('{h}', '$artworkSize'),
    );
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
