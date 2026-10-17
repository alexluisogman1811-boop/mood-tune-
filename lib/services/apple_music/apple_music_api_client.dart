import 'package:dio/dio.dart';

import '../../core/errors/app_failure.dart';
import 'apple_music_tokens.dart';

/// Minimal wrapper over the Apple Music API endpoints MoodScape uses.
/// Catalogue search needs only a developer token; library edits also need a
/// Music User Token.
class AppleMusicApiClient {
  AppleMusicApiClient({
    required this._dio,
    required this._developerTokens,
    required this._userTokens,
  });

  static const _host = 'api.music.apple.com';
  static const maxSearchLimit = 25;
  static final _storefrontPattern = RegExp(r'^[a-z]{2}$');

  final Dio _dio;
  final AppleDeveloperTokenProvider _developerTokens;
  final AppleMusicUserTokenStore _userTokens;

  static bool isValidStorefront(String s) => _storefrontPattern.hasMatch(s);

  /// Raw song resources from `GET /v1/catalog/{storefront}/search`.
  Future<List<Map<String, Object?>>> searchSongs(
    String term, {
    required String storefront,
    int offset = 0,
    int limit = maxSearchLimit,
  }) async {
    if (!isValidStorefront(storefront)) {
      throw const InvalidResponseFailure('Unknown Apple Music storefront.');
    }
    final data = await _send(
      'GET',
      '/v1/catalog/$storefront/search',
      query: {
        'term': term,
        'types': 'songs',
        'limit': '${limit.clamp(1, maxSearchLimit)}',
        'offset': '$offset',
      },
    );
    if (data is! Map) throw const InvalidResponseFailure();
    final results = data['results'];
    // Apple omits a type entirely when it has no matches.
    final songs = results is Map ? results['songs'] : null;
    final items = songs is Map ? songs['data'] : null;
    if (items == null) return const [];
    if (items is! List) throw const InvalidResponseFailure();
    return [
      for (final item in items)
        if (item is Map) item.cast<String, Object?>(),
    ];
  }

  /// The signed-in user's storefront (e.g. "us"), or null.
  Future<String?> userStorefront() async {
    final data = await _send('GET', '/v1/me/storefront', needsUser: true);
    final list = data is Map ? data['data'] : null;
    final id = list is List && list.isNotEmpty && list.first is Map
        ? (list.first as Map)['id']
        : null;
    return id is String && isValidStorefront(id) ? id : null;
  }

  /// Creates a library playlist containing [songIds] (catalogue ids).
  Future<String> createLibraryPlaylist({
    required String name,
    required String description,
    required List<String> songIds,
  }) async {
    final data = await _send(
      'POST',
      '/v1/me/library/playlists',
      needsUser: true,
      body: {
        'attributes': {'name': name, 'description': description},
        'relationships': {
          'tracks': {
            'data': [
              for (final id in songIds) {'id': id, 'type': 'songs'},
            ],
          },
        },
      },
    );
    final list = data is Map ? data['data'] : null;
    final id = list is List && list.isNotEmpty && list.first is Map
        ? (list.first as Map)['id']
        : null;
    if (id is! String || id.isEmpty) throw const InvalidResponseFailure();
    return id;
  }

  Future<void> addToLibraryPlaylist(String playlistId, List<String> songIds) =>
      _send(
        'POST',
        '/v1/me/library/playlists/${Uri.encodeComponent(playlistId)}/tracks',
        needsUser: true,
        body: {
          'data': [
            for (final id in songIds) {'id': id, 'type': 'songs'},
          ],
        },
      );

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool needsUser = false,
  }) async {
    final uri = Uri.https(_host, path, query);
    String? userToken;
    if (needsUser) {
      userToken = await _userTokens.read();
      if (userToken == null) {
        throw const AuthFailure('Connect Apple Music to use your library.');
      }
    }
    for (var attempt = 0; ; attempt++) {
      final dev = await _developerTokens.token();
      try {
        final res = await _dio.requestUri<Object?>(
          uri,
          data: body,
          options: Options(
            method: method,
            headers: {
              'Authorization': 'Bearer $dev',
              'Music-User-Token': ?userToken,
            },
          ),
        );
        return res.data;
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 401 && attempt == 0 && !needsUser) {
          _developerTokens.invalidate();
          continue;
        }
        if (status == 401 && needsUser) {
          // The user token was revoked or expired.
          await _userTokens.clear();
          throw const AuthFailure('Please reconnect Apple Music.');
        }
        throw _mapError(status);
      }
    }
  }

  static AppFailure _mapError(int? status) => switch (status) {
    401 => const AuthFailure('Apple Music rejected the developer token.'),
    403 => const AuthFailure(
      'Apple Music denied access. Saving to your library needs an active '
      'Apple Music subscription.',
    ),
    404 => const InvalidResponseFailure('Not available in your region.'),
    429 => const NetworkFailure('Apple Music is busy. Try again shortly.'),
    null => const NetworkFailure('Could not reach Apple Music.'),
    _ when status >= 500 => const NetworkFailure(
      'Apple Music is having problems. Try again later.',
    ),
    _ => const InvalidResponseFailure('Apple Music rejected the request.'),
  };
}
