import 'package:flutter_test/flutter_test.dart';
import 'package:moodscape/features/recommendations/domain/playlist_export.dart';
import 'package:moodscape/features/recommendations/domain/track.dart';

Track _t(String title, String artist) => Track(
  id: title,
  title: title,
  artist: artist,
  provider: MusicProvider.demo,
);

void main() {
  test('one "Artist - Title" line per song, in playlist order', () {
    expect(
      PlaylistExport.asText([
        _t('So What', 'Miles Davis'),
        _t('Take Five', 'The Dave Brubeck Quartet'),
      ]),
      'Miles Davis - So What\nThe Dave Brubeck Quartet - Take Five',
    );
  });

  test('line breaks and extra spaces inside names never split a song', () {
    expect(
      PlaylistExport.asText([_t('Song\nName  ', ' Some   Artist')]),
      'Some Artist - Song Name',
    );
  });

  test('empty playlist exports as empty text', () {
    expect(PlaylistExport.asText(const []), isEmpty);
  });

  test('points at the free transfer tool over HTTPS', () {
    expect(PlaylistExport.transferToolUrl.scheme, 'https');
    expect(PlaylistExport.transferToolUrl.host, 'www.tunemymusic.com');
  });
}
