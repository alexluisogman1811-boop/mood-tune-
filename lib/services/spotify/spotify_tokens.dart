import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/errors/app_failure.dart';

class SpotifyTokens {
  const SpotifyTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.scopes,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final Set<String> scopes;

  /// Treat tokens as expired a minute early to avoid racing the expiry.
  bool isExpired(DateTime now) =>
      !now.isBefore(expiresAt.subtract(const Duration(minutes: 1)));

  /// Parses Spotify's token endpoint response. On refresh the response may
  /// omit `refresh_token`; then [previousRefreshToken] is kept.
  factory SpotifyTokens.fromTokenResponse(
    Object? json, {
    required DateTime now,
    String? previousRefreshToken,
  }) {
    if (json is! Map) throw const InvalidResponseFailure();
    final access = json['access_token'];
    final expiresIn = json['expires_in'];
    final refresh = json['refresh_token'] ?? previousRefreshToken;
    if (access is! String ||
        access.isEmpty ||
        expiresIn is! int ||
        expiresIn <= 0 ||
        refresh is! String ||
        refresh.isEmpty) {
      throw const InvalidResponseFailure('Spotify returned an invalid token.');
    }
    final scope = json['scope'];
    return SpotifyTokens(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: now.add(Duration(seconds: expiresIn)),
      scopes: scope is String
          ? scope.split(' ').where((s) => s.isNotEmpty).toSet()
          : const {},
    );
  }

  Map<String, Object> toJson() => {
    'access': accessToken,
    'refresh': refreshToken,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'scopes': scopes.toList(),
  };

  static SpotifyTokens? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final access = json['access'], refresh = json['refresh'];
    final expires = DateTime.tryParse('${json['expiresAt']}');
    if (access is! String || refresh is! String || expires == null) return null;
    final scopes = json['scopes'];
    return SpotifyTokens(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expires,
      scopes: scopes is List ? scopes.whereType<String>().toSet() : const {},
    );
  }

  /// Never print tokens.
  @override
  String toString() => 'SpotifyTokens(expiresAt: $expiresAt, scopes: $scopes)';
}

/// Keychain / Keystore-backed token persistence.
class SpotifyTokenStore {
  const SpotifyTokenStore(this._storage);

  static const _key = 'spotify.tokens.v1';
  final FlutterSecureStorage _storage;

  Future<SpotifyTokens?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return SpotifyTokens.tryFromJson(jsonDecode(raw));
    } on FormatException {
      await clear();
      return null;
    }
  }

  Future<void> write(SpotifyTokens tokens) =>
      _storage.write(key: _key, value: jsonEncode(tokens.toJson()));

  Future<void> clear() => _storage.delete(key: _key);
}
