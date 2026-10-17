import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/errors/app_failure.dart';
import 'musickit_bridge.dart';

/// Supplies the Apple Music developer token (a JWT signed with a MusicKit
/// private key). The key never ships in the app:
/// * iOS: MusicKit generates the token natively.
/// * Elsewhere: an HTTPS backend at [backendUrl] returns `{"token": "…"}`.
/// Tokens are cached in memory only, until shortly before they expire.
class AppleDeveloperTokenProvider {
  AppleDeveloperTokenProvider({
    required this._native,
    required this._dio,
    this.backendUrl,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final MusicKitBridge _native;
  final Dio _dio;
  final Uri? backendUrl;
  final DateTime Function() _clock;

  String? _token;
  DateTime? _expiresAt;

  bool get isAvailable => _native.isSupported || _backendOk;

  bool get _backendOk =>
      backendUrl != null &&
      backendUrl!.scheme == 'https' &&
      backendUrl!.host.isNotEmpty;

  Future<String> token() async {
    final cached = _token, exp = _expiresAt;
    if (cached != null && exp != null && _clock().isBefore(exp)) return cached;

    final String fresh;
    if (_native.isSupported) {
      fresh = await _native.developerToken();
    } else if (_backendOk) {
      fresh = await _fromBackend();
    } else {
      throw const NotConfiguredFailure(
        'Apple Music is not set up for this build.',
      );
    }
    _token = fresh;
    // Unknown expiry: assume a short lifetime rather than trusting it long.
    _expiresAt = (jwtExpiry(fresh) ?? _clock().add(const Duration(minutes: 30)))
        .subtract(const Duration(minutes: 5));
    return fresh;
  }

  /// Forget the cached token (e.g. after a 401).
  void invalidate() {
    _token = null;
    _expiresAt = null;
  }

  Future<String> _fromBackend() async {
    try {
      final res = await _dio.getUri<Object?>(backendUrl!);
      final data = res.data;
      final token = data is Map ? data['token'] : null;
      if (token is! String || token.split('.').length != 3) {
        throw const InvalidResponseFailure(
          'The Apple Music token service returned an invalid token.',
        );
      }
      return token;
    } on DioException {
      throw const NetworkFailure(
        'Could not reach the Apple Music token service.',
      );
    }
  }

  /// Reads the `exp` claim without verifying the signature (Apple does that).
  static DateTime? jwtExpiry(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = payload is Map ? payload['exp'] : null;
      return exp is int
          ? DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true)
          : null;
    } on FormatException {
      return null;
    }
  }
}

/// The Music User Token lets MoodScape edit the user's library. Stored in
/// Keychain/Keystore; removed on disconnect or when Apple rejects it.
class AppleMusicUserTokenStore {
  const AppleMusicUserTokenStore(this._storage);

  static const _key = 'apple_music.user_token.v1';
  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  Future<void> clear() => _storage.delete(key: _key);
}
