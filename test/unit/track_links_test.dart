import 'package:flutter_test/flutter_test.dart';
import 'package:moodscape/core/links/url_opener.dart';
import 'package:moodscape/features/recommendations/data/track_links.dart';
import 'package:moodscape/features/recommendations/domain/track.dart';

Track _track({
  required String title,
  required String artist,
  MusicProvider provider = MusicProvider.demo,
  Uri? externalUrl,
}) => Track(
  id: 'id',
  title: title,
  artist: artist,
  provider: provider,
  externalUrl: externalUrl,
);

void main() {
  group('Spotify search link', () {
    test('a plain name becomes one search path', () {
      final uri = TrackLinks.spotify(
        _track(title: 'Teenagers', artist: 'My Chemical Romance'),
      );

      expect(uri.host, 'open.spotify.com');
      expect(uri.pathSegments, ['search', 'Teenagers My Chemical Romance']);
    });

    test('a slash in the artist stays inside the search words', () {
      final uri = TrackLinks.spotify(
        _track(title: 'Thunderstruck', artist: 'AC/DC'),
      );

      // Two segments only: a third would make Spotify show an error page.
      expect(uri.pathSegments, ['search', 'Thunderstruck AC/DC']);
      expect(uri.toString(), contains('AC%2FDC'));
    });

    test('a slash in the title stays inside the search words', () {
      final uri = TrackLinks.spotify(
        _track(
          title: 'Mayonaka no Door / Stay With Me',
          artist: 'Miki Matsubara',
        ),
      );

      expect(uri.pathSegments.length, 2);
      expect(uri.pathSegments.last, contains('/'));
    });

    test('a question mark survives the trip', () {
      final uri = TrackLinks.spotify(
        _track(title: 'Where Is My Mind?', artist: 'Pixies'),
      );

      expect(uri.pathSegments.last, 'Where Is My Mind? Pixies');
      expect(uri.query, isEmpty);
    });

    test("a Spotify track uses the provider's own link", () {
      final deep = Uri.parse('https://open.spotify.com/track/abc');
      final uri = TrackLinks.spotify(
        _track(
          title: 'Any',
          artist: 'Any',
          provider: MusicProvider.spotify,
          externalUrl: deep,
        ),
      );

      expect(uri, deep);
    });
  });

  group('which links must stay in a browser', () {
    test('a Spotify search link does', () {
      final uri = TrackLinks.spotify(
        _track(title: 'Thunderstruck', artist: 'AC/DC'),
      );

      expect(needsBrowser(uri), isTrue);
    });

    test('a Spotify link to one track does not', () {
      final uri = TrackLinks.spotify(
        _track(
          title: 'Any',
          artist: 'Any',
          provider: MusicProvider.spotify,
          externalUrl: Uri.parse('https://open.spotify.com/track/abc'),
        ),
      );

      expect(needsBrowser(uri), isFalse);
    });

    test('an Apple Music search link does not', () {
      final uri = TrackLinks.appleMusic(
        _track(title: 'Thunderstruck', artist: 'AC/DC'),
      );

      // Apple Music opens search in its own app correctly.
      expect(needsBrowser(uri), isFalse);
    });

    test('a preview audio link does not', () {
      expect(
        needsBrowser(Uri.parse('https://cdn.deezer.com/p/1.mp3')),
        isFalse,
      );
    });
  });

  group('Apple Music search link', () {
    test('the words go in the term parameter', () {
      final uri = TrackLinks.appleMusic(
        _track(title: 'Thunderstruck', artist: 'AC/DC'),
      );

      expect(uri.host, 'music.apple.com');
      expect(uri.path, '/search');
      expect(uri.queryParameters['term'], 'Thunderstruck AC/DC');
    });

    test("an Apple Music track uses the provider's own link", () {
      final deep = Uri.parse('https://music.apple.com/song/1');
      final uri = TrackLinks.appleMusic(
        _track(
          title: 'Any',
          artist: 'Any',
          provider: MusicProvider.appleMusic,
          externalUrl: deep,
        ),
      );

      expect(uri, deep);
    });
  });
}
