import 'track.dart';

/// Plain-text playlist for importing into Spotify (or any service) with a
/// free transfer tool such as TuneMyMusic, without needing Spotify API
/// access. One "Artist - Title" line per song, the format those tools match.
abstract final class PlaylistExport {
  static final transferToolUrl = Uri.https('www.tunemymusic.com', '/');

  static String asText(Iterable<Track> tracks) =>
      [for (final t in tracks) '${_clean(t.artist)} - ${_clean(t.title)}']
          .join('\n');

  /// Line breaks inside a field would split one song into two lines.
  static String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
}
