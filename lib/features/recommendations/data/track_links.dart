import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/track.dart';

/// Builds "open in" links. Uses the provider's deep link when a track came
/// from that service; otherwise falls back to the service's public search.
abstract final class TrackLinks {
  static Uri spotify(Track t) =>
      t.provider == MusicProvider.spotify && t.externalUrl != null
      ? t.externalUrl!
      : Uri.https('open.spotify.com', '/search/${t.title} ${t.artist}');

  static Uri appleMusic(Track t) =>
      t.provider == MusicProvider.appleMusic && t.externalUrl != null
      ? t.externalUrl!
      : Uri.https('music.apple.com', '/search', {
          'term': '${t.title} ${t.artist}',
        });
}

typedef UrlOpener = Future<bool> Function(Uri uri);

/// Injectable so tests never launch real apps.
final urlOpenerProvider = Provider<UrlOpener>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
