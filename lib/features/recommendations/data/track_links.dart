import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/track.dart';

/// Builds "open in" links. Uses the provider's deep link when a track came
/// from that service; otherwise falls back to the service's public search.
abstract final class TrackLinks {
  /// Spotify puts the search words in the path, so they go in as ONE path
  /// segment. A slash in a name ("AC/DC", "Mayonaka no Door / Stay With Me")
  /// would otherwise read as a second segment and Spotify shows an error
  /// page instead of the search.
  static Uri spotify(Track t) =>
      t.provider == MusicProvider.spotify && t.externalUrl != null
      ? t.externalUrl!
      : Uri(
          scheme: 'https',
          host: 'open.spotify.com',
          pathSegments: ['search', _query(t)],
        );

  /// Apple Music takes the words as a query parameter, which is escaped for
  /// us, so a slash is safe here.
  static Uri appleMusic(Track t) =>
      t.provider == MusicProvider.appleMusic && t.externalUrl != null
      ? t.externalUrl!
      : Uri.https('music.apple.com', '/search', {'term': _query(t)});

  static String _query(Track t) => '${t.title} ${t.artist}';
}

typedef UrlOpener = Future<bool> Function(Uri uri);

/// Injectable so tests never launch real apps.
final urlOpenerProvider = Provider<UrlOpener>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
