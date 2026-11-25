import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a link outside the app.
typedef UrlOpener = Future<bool> Function(Uri uri);

/// True for a link that has to be shown in a browser instead of being handed
/// to whichever app claims it.
///
/// On Android the Spotify app claims every open.spotify.com link, but its own
/// screens cannot show a search page, so handing one over gives the user
/// "this doesn't exist". iOS does not claim the path, which is why the same
/// link works there. A link to one track is the opposite case: the app shows
/// it properly, so that one is still handed over.
bool needsBrowser(Uri uri) =>
    uri.host == 'open.spotify.com' &&
    uri.pathSegments.isNotEmpty &&
    uri.pathSegments.first == 'search';

/// Injectable so tests never launch real apps.
final urlOpenerProvider = Provider<UrlOpener>(
  (ref) => (uri) => launchUrl(
    uri,
    mode: needsBrowser(uri)
        ? LaunchMode.inAppBrowserView
        : LaunchMode.externalApplication,
  ),
);
