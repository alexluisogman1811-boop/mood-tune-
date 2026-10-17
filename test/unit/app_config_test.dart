import 'package:flutter_test/flutter_test.dart';
import 'package:moodscape/core/configuration/app_config.dart';

AppConfig _config({
  String spotifyClientId = '',
  String spotifyRedirectUri = '',
  String analysisBackendUrl = '',
  String appleTokenUrl = '',
}) => AppConfig(
  spotifyClientId: spotifyClientId,
  spotifyRedirectUri: spotifyRedirectUri,
  analysisBackendUrl: analysisBackendUrl,
  appleMusicDeveloperTokenUrl: appleTokenUrl,
);

void main() {
  test('empty config reports nothing configured', () {
    final config = _config();
    expect(config.hasSpotify, isFalse);
    expect(config.hasAnalysisBackend, isFalse);
    expect(config.hasAppleMusicTokenService, isFalse);
  });

  test('Spotify needs both client id and redirect uri', () {
    expect(_config(spotifyClientId: 'abc').hasSpotify, isFalse);
    expect(
      _config(
        spotifyClientId: 'abc',
        spotifyRedirectUri: 'moodscape://callback',
      ).hasSpotify,
      isTrue,
    );
  });

  test('backend URLs must be HTTPS', () {
    expect(
      _config(analysisBackendUrl: 'http://example.com').hasAnalysisBackend,
      isFalse,
    );
    expect(
      _config(analysisBackendUrl: 'not a url').hasAnalysisBackend,
      isFalse,
    );
    expect(
      _config(analysisBackendUrl: 'https://api.example.com').hasAnalysisBackend,
      isTrue,
    );
  });
}
