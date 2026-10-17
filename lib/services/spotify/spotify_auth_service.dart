import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../../core/errors/app_failure.dart';
import 'pkce.dart';
import 'spotify_tokens.dart';

/// Opens [url] in a system browser session and returns the full callback URL
/// once the browser is redirected to [callbackScheme].
typedef WebAuthLauncher = Future<String> Function(
  Uri url,
  String callbackScheme,
);

/// Authorization Code + PKCE (no client secret on the device).
class SpotifyAuthService {
  SpotifyAuthService({
    required this.clientId,
    required this.redirectUri,
    required this._dio,
    required this._store,
    required this._launcher,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static final authorizeEndpoint = Uri.https(
    'accounts.spotify.com',
    '/authorize',
  );
  static final tokenEndpoint = Uri.https('accounts.spotify.com', '/api/token');

  /// Only what MoodScape needs: create playlists and add songs to them.
  static const scopes = ['playlist-modify-private', 'playlist-modify-public'];

  final String clientId;
  final String redirectUri;
  final Dio _dio;
  final SpotifyTokenStore _store;
  final WebAuthLauncher _launcher;
  final DateTime Function() _clock;

  Future<bool> isConnected() async => await _store.read() != null;

  Uri buildAuthorizeUrl({required String challenge, required String state}) =>
      authorizeEndpoint.replace(
        queryParameters: {
          'client_id': clientId,
          'response_type': 'code',
          'redirect_uri': redirectUri,
          'code_challenge_method': 'S256',
          'code_challenge': challenge,
          'state': state,
          'scope': scopes.join(' '),
        },
      );

  /// Runs the full sign-in. Throws [AuthCancelledFailure] if the user backs
  /// out, [AuthFailure] if Spotify refuses, [NetworkFailure] when offline.
  Future<SpotifyTokens> connect() async {
    final verifier = Pkce.generateVerifier();
    final state = Pkce.generateState();
    final url = buildAuthorizeUrl(
      challenge: Pkce.challengeFor(verifier),
      state: state,
    );

    final String callback;
    try {
      callback = await _launcher(url, Uri.parse(redirectUri).scheme);
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') throw const AuthCancelledFailure();
      throw const UnsupportedPlatformFailure(
        'Could not open the Spotify sign-in page on this device.',
      );
    }

    final params = Uri.parse(callback).queryParameters;
    if (params['state'] != state) {
      throw const AuthFailure('Sign-in response did not match. Try again.');
    }
    final error = params['error'];
    if (error == 'access_denied') throw const AuthCancelledFailure();
    final code = params['code'];
    if (error != null || code == null || code.isEmpty) {
      throw const AuthFailure('Spotify did not authorise MoodScape.');
    }

    final tokens = await _requestTokens({
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri,
      'client_id': clientId,
      'code_verifier': verifier,
    });
    await _store.write(tokens);
    return tokens;
  }

  /// A non-expired access token, refreshing if needed. Throws [AuthFailure]
  /// (and forgets the tokens) if access was revoked.
  Future<String> validAccessToken({bool forceRefresh = false}) async {
    final inFlight = _refreshing;
    if (inFlight != null) return (await inFlight).accessToken;

    final tokens = await _store.read();
    if (tokens == null) throw const AuthFailure('Spotify is not connected.');
    if (!forceRefresh && !tokens.isExpired(_clock())) return tokens.accessToken;

    // Single-flight: concurrent callers share one refresh, so a rotated
    // refresh token is never used twice.
    final refresh = _refreshing ??= _refresh(tokens);
    try {
      return (await refresh).accessToken;
    } finally {
      if (identical(_refreshing, refresh)) _refreshing = null;
    }
  }

  Future<SpotifyTokens>? _refreshing;

  Future<SpotifyTokens> _refresh(SpotifyTokens tokens) async {
    final refreshed = await _requestTokens({
      'grant_type': 'refresh_token',
      'refresh_token': tokens.refreshToken,
      'client_id': clientId,
    }, previousRefreshToken: tokens.refreshToken);
    await _store.write(refreshed);
    return refreshed;
  }

  /// Forgets tokens on this device. Spotify offers no revoke endpoint for
  /// PKCE apps; users can also remove access at spotify.com/account/apps.
  Future<void> disconnect() => _store.clear();

  Future<SpotifyTokens> _requestTokens(
    Map<String, String> form, {
    String? previousRefreshToken,
  }) async {
    try {
      final response = await _dio.postUri<Object?>(
        tokenEndpoint,
        data: form,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return SpotifyTokens.fromTokenResponse(
        response.data,
        now: _clock(),
        previousRefreshToken: previousRefreshToken,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 401) {
        // invalid_grant: refresh token revoked or expired.
        await _store.clear();
        throw const AuthFailure();
      }
      throw const NetworkFailure('Could not reach Spotify. Try again.');
    }
  }
}
