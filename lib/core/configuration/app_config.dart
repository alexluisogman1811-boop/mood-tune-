/// Build-time configuration supplied with `--dart-define-from-file`.
///
/// Only public identifiers belong here (client IDs, redirect URIs, backend
/// URLs). Secret keys must live on a backend service, never in the app.
class AppConfig {
  const AppConfig({
    required this.spotifyClientId,
    required this.spotifyRedirectUri,
    required this.analysisBackendUrl,
    required this.appleMusicDeveloperTokenUrl,
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    spotifyClientId: String.fromEnvironment('SPOTIFY_CLIENT_ID'),
    spotifyRedirectUri: String.fromEnvironment('SPOTIFY_REDIRECT_URI'),
    analysisBackendUrl: String.fromEnvironment('ANALYSIS_BACKEND_URL'),
    appleMusicDeveloperTokenUrl: String.fromEnvironment(
      'APPLE_MUSIC_DEVELOPER_TOKEN_URL',
    ),
  );

  final String spotifyClientId;
  final String spotifyRedirectUri;
  final String analysisBackendUrl;
  final String appleMusicDeveloperTokenUrl;

  bool get hasSpotify =>
      spotifyClientId.isNotEmpty && spotifyRedirectUri.isNotEmpty;

  /// Remote analysis is only allowed over HTTPS.
  bool get hasAnalysisBackend => _isHttps(analysisBackendUrl);

  bool get hasAppleMusicTokenService => _isHttps(appleMusicDeveloperTokenUrl);

  static bool _isHttps(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}
