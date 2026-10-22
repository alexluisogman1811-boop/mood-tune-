/// Build-time configuration supplied with `--dart-define-from-file`.
///
/// Only public identifiers belong here (client IDs, redirect URIs, backend
/// URLs). Secret keys must live on a backend service, never in the app.
/// Firebase web settings are public by design; the database rules
/// (firestore.rules) are what protect the data.
class AppConfig {
  const AppConfig({
    required this.spotifyClientId,
    required this.spotifyRedirectUri,
    required this.analysisBackendUrl,
    required this.appleMusicDeveloperTokenUrl,
    this.feedbackUrl = '',
    this.firebaseApiKey = '',
    this.firebaseAppId = '',
    this.firebaseAndroidAppId = '',
    this.firebaseProjectId = '',
    this.firebaseMessagingSenderId = '',
    this.firebaseAuthDomain = '',
    this.adminEmails = '',
    this.paymentInfo = '',
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    spotifyClientId: String.fromEnvironment('SPOTIFY_CLIENT_ID'),
    spotifyRedirectUri: String.fromEnvironment('SPOTIFY_REDIRECT_URI'),
    analysisBackendUrl: String.fromEnvironment('ANALYSIS_BACKEND_URL'),
    appleMusicDeveloperTokenUrl: String.fromEnvironment(
      'APPLE_MUSIC_DEVELOPER_TOKEN_URL',
    ),
    feedbackUrl: String.fromEnvironment('FEEDBACK_URL'),
    firebaseApiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    firebaseAppId: String.fromEnvironment('FIREBASE_APP_ID'),
    firebaseAndroidAppId: String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
    firebaseProjectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    firebaseMessagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    ),
    firebaseAuthDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    adminEmails: String.fromEnvironment('ADMIN_EMAILS'),
    paymentInfo: String.fromEnvironment('PAYMENT_INFO'),
  );

  final String spotifyClientId;
  final String spotifyRedirectUri;
  final String analysisBackendUrl;
  final String appleMusicDeveloperTokenUrl;

  /// Google Apps Script web app that collects feedback (tool/feedback_backend).
  final String feedbackUrl;

  /// Firebase project used for accounts and plans. All empty means accounts
  /// are switched off and everything is unlocked (development builds).
  final String firebaseApiKey;
  final String firebaseAppId;

  /// Optional separate Android app id; the web app id is used otherwise.
  final String firebaseAndroidAppId;
  final String firebaseProjectId;
  final String firebaseMessagingSenderId;
  final String firebaseAuthDomain;

  /// Comma-separated emails that may open the admin page. The database
  /// rules hold the same list; that is what actually grants access.
  final String adminEmails;

  /// How to pay, shown on the upgrade screen (e.g. PromptPay number).
  final String paymentInfo;

  bool get hasSpotify =>
      spotifyClientId.isNotEmpty && spotifyRedirectUri.isNotEmpty;

  /// Remote analysis is only allowed over HTTPS.
  bool get hasAnalysisBackend => _isHttps(analysisBackendUrl);

  bool get hasAppleMusicTokenService => _isHttps(appleMusicDeveloperTokenUrl);

  bool get hasFeedbackBackend => _isHttps(feedbackUrl);

  bool get hasAccounts =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;

  Set<String> get adminEmailSet => {
    for (final e in adminEmails.split(','))
      if (e.trim().isNotEmpty) e.trim().toLowerCase(),
  };

  static bool _isHttps(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}
