import 'package:dio/dio.dart';

import '../../core/errors/app_failure.dart';
import 'spotify_auth_service.dart';

/// Minimal, typed wrapper over the Spotify Web API endpoints MoodScape uses.
/// Endpoint paths follow the February 2026 Web API changes:
/// `POST /me/playlists` and `POST /playlists/{id}/items`; search returns at
/// most 10 items per page.
class SpotifyApiClient {
  SpotifyApiClient({required this._dio, required this._auth});

  static const _host = 'api.spotify.com';
  static const maxSearchLimit = 10;
  static const maxItemsPerAdd = 100;

  final Dio _dio;
  final SpotifyAuthService _auth;

  /// Raw track objects from `GET /search?type=track`.
  Future<List<Map<String, Object?>>> searchTracks(
    String query, {
    int offset = 0,
    int limit = maxSearchLimit,
  }) async {
    final data = await _send(
      'GET',
      '/v1/search',
      query: {
        'q': query,
        'type': 'track',
        'limit': '${limit.clamp(1, maxSearchLimit)}',
        'offset': '$offset',
      },
    );
    final tracks = data is Map ? data['tracks'] : null;
    final items = tracks is Map ? tracks['items'] : null;
    if (items is! List) throw const InvalidResponseFailure();
    return [
      for (final item in items)
        if (item is Map) item.cast<String, Object?>(),
    ];
  }

  /// The signed-in user's display name, if Spotify provides one.
  Future<String?> displayName() async {
    final data = await _send('GET', '/v1/me');
    final name = data is Map ? data['display_name'] : null;
    return name is String && name.isNotEmpty ? name : null;
  }

  /// Creates a playlist for the current user and returns its id and URL.
  Future<({String id, Uri? url})> createPlaylist({
    required String name,
    required String description,
    bool public = false,
  }) async {
    final data = await _send(
      'POST',
      '/v1/me/playlists',
      body: {'name': name, 'description': description, 'public': public},
    );
    final id = data is Map ? data['id'] : null;
    if (id is! String || id.isEmpty) throw const InvalidResponseFailure();
    final ext = data is Map ? data['external_urls'] : null;
    final url = ext is Map ? Uri.tryParse('${ext['spotify']}') : null;
    return (id: id, url: url);
  }

  /// Adds Spotify track URIs, chunked to the API's 100-item limit.
  Future<void> addItems(String playlistId, List<String> uris) async {
    for (var i = 0; i < uris.length; i += maxItemsPerAdd) {
      await _send(
        'POST',
        '/v1/playlists/${Uri.encodeComponent(playlistId)}/items',
        body: {
          'uris': uris.sublist(i, (i + maxItemsPerAdd).clamp(0, uris.length)),
        },
      );
    }
  }

  /// Removes every occurrence of the given track URIs from a playlist the
  /// user owns. `DELETE /playlists/{id}/items` with `{"items": [{"uri"}]}`
  /// (the body key was renamed from `tracks` in February 2026).
  Future<void> removeItems(String playlistId, List<String> uris) async {
    for (var i = 0; i < uris.length; i += maxItemsPerAdd) {
      final chunk = uris.sublist(i, (i + maxItemsPerAdd).clamp(0, uris.length));
      await _send(
        'DELETE',
        '/v1/playlists/${Uri.encodeComponent(playlistId)}/items',
        body: {
          'items': [
            for (final uri in chunk) {'uri': uri},
          ],
        },
      );
    }
  }

  /// Sends an authorised request; on 401 refreshes once and retries.
  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final uri = Uri.https(_host, path, query);
    for (var attempt = 0; ; attempt++) {
      final token = await _auth.validAccessToken(forceRefresh: attempt > 0);
      try {
        final response = await _dio.requestUri<Object?>(
          uri,
          data: body,
          options: Options(
            method: method,
            headers: {'Authorization': 'Bearer $token'},
          ),
        );
        return response.data;
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 401 && attempt == 0) continue;
        throw _mapError(e);
      }
    }
  }

  static AppFailure _mapError(DioException e) {
    final status = e.response?.statusCode;
    return switch (status) {
      401 => const AuthFailure(),
      403 => const AuthFailure(
        'Spotify refused access. Apps in Development Mode only work for '
        'accounts added to the app\'s user list in the Spotify dashboard.',
      ),
      429 => NetworkFailure(
        'Spotify is busy. Try again in '
        '${e.response?.headers.value('retry-after') ?? 'a few'} seconds.',
      ),
      null => const NetworkFailure('Could not reach Spotify.'),
      _ when status >= 500 => const NetworkFailure(
        'Spotify is having problems. Try again later.',
      ),
      _ => const InvalidResponseFailure('Spotify rejected the request.'),
    };
  }
}
