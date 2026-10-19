import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/l10n/translate.dart';
import '../../mood/application/mood_controller.dart';
import '../../mood/domain/mood.dart';
import '../../music_platform/application/apple_music_providers.dart';
import '../../music_platform/application/platform_providers.dart';
import '../domain/track.dart';

/// Outcome of a playlist action, for a snackbar. [template] is English with
/// `{name}` placeholders filled from [args], so it can be shown in any
/// language.
class PlaylistResult {
  const PlaylistResult(this.template, {this.args = const {}, this.url});
  final String template;
  final Map<String, Object?> args;
  final Uri? url;

  /// The message in English.
  String get message => wordedIn('en');

  /// The message in [languageCode]; text arguments are translated too.
  String wordedIn(String languageCode) => translate(template, languageCode, {
    for (final MapEntry(:key, :value) in args.entries)
      key: value is String ? translate(value, languageCode) : value,
  });
}

/// Whether songs from [provider] can be saved to a playlist right now.
final canSavePlaylistProvider = Provider.family<bool, MusicProvider>((
  ref,
  provider,
) {
  return switch (provider) {
    MusicProvider.spotify =>
      (ref.watch(spotifyConnectionProvider).value?.connected ?? false) &&
          ref.watch(spotifyApiClientProvider) != null,
    MusicProvider.appleMusic =>
      (ref.watch(appleMusicConnectionProvider).value?.authorized ?? false) &&
          ref.watch(appleMusicApiClientProvider) != null,
    MusicProvider.demo => false,
  };
});

/// Playlists created in this session, per service, so repeated "add" taps
/// go to the same playlist.
final playlistControllerProvider =
    NotifierProvider<PlaylistController, Map<MusicProvider, String>>(
      PlaylistController.new,
    );

class PlaylistController extends Notifier<Map<MusicProvider, String>> {
  @override
  Map<MusicProvider, String> build() => const {};

  static const _description = 'Made with MoodScape';

  /// Saves [tracks] (all from one service) as a new private playlist.
  Future<PlaylistResult> saveAll(List<Track> tracks) async {
    final provider = tracks.isEmpty ? null : tracks.first.provider;
    final ids = _ids(tracks, provider);
    if (provider == null ||
        ids.isEmpty ||
        !ref.read(canSavePlaylistProvider(provider))) {
      return const PlaylistResult('Connect a music service to save playlists.');
    }
    try {
      final created = await _create(provider, ids);
      state = {...state, provider: created.id};
      return PlaylistResult(
        'Saved {count} songs to {service}.',
        args: {'count': ids.length, 'service': _serviceName(provider)},
        url: created.url,
      );
    } on AppFailure catch (e) {
      return PlaylistResult(e.message);
    }
  }

  /// Adds one song to this session's playlist, creating it on first use.
  Future<PlaylistResult> add(Track track) async {
    final provider = track.provider;
    final ids = _ids([track], provider);
    if (ids.isEmpty || !ref.read(canSavePlaylistProvider(provider))) {
      return const PlaylistResult('Connect a music service to add songs.');
    }
    try {
      final existing = state[provider];
      if (existing == null) {
        final created = await _create(provider, ids);
        state = {...state, provider: created.id};
      } else {
        await _append(provider, existing, ids);
      }
      return PlaylistResult(
        'Added to your MoodScape playlist on {service}.',
        args: {'service': _serviceName(provider)},
      );
    } on AppFailure catch (e) {
      return PlaylistResult(e.message);
    }
  }

  /// Keeps this session's saved playlist in step with a dislike (or its
  /// undo): removes [removed] and adds [added]. Returns null when no
  /// playlist was saved for that service, so there is nothing to update.
  Future<PlaylistResult?> swap({Track? removed, Track? added}) async {
    final provider = (removed ?? added)?.provider;
    if (provider == null) return null;
    final playlistId = state[provider];
    if (playlistId == null || !ref.read(canSavePlaylistProvider(provider))) {
      return null;
    }
    final removeIds = removed == null
        ? const <String>[]
        : _ids([removed], provider);
    final addIds = added == null ? const <String>[] : _ids([added], provider);
    try {
      switch (provider) {
        case MusicProvider.spotify:
          final client = ref.read(spotifyApiClientProvider)!;
          if (removeIds.isNotEmpty) {
            await client.removeItems(playlistId, removeIds);
          }
          if (addIds.isNotEmpty) await client.addItems(playlistId, addIds);
          return const PlaylistResult('Your Spotify playlist was updated too.');
        case MusicProvider.appleMusic:
          // Apple Music's API can add to library playlists but not remove.
          if (addIds.isNotEmpty) await _append(provider, playlistId, addIds);
          if (removeIds.isEmpty) return null;
          return const PlaylistResult(
            'Apple Music doesn\'t let apps remove songs from playlists — '
            'remove it in the Music app.',
          );
        case MusicProvider.demo:
          return null;
      }
    } on AppFailure catch (e) {
      return PlaylistResult(
        'Playlist not updated: {error}',
        args: {'error': e.message},
      );
    }
  }

  static List<String> _ids(Iterable<Track> tracks, MusicProvider? provider) => [
    for (final t in tracks)
      if (t.provider == provider && t.providerUri != null) t.providerUri!,
  ];

  Future<({String id, Uri? url})> _create(
    MusicProvider provider,
    List<String> ids,
  ) async {
    switch (provider) {
      case MusicProvider.spotify:
        final client = ref.read(spotifyApiClientProvider)!;
        final created = await client.createPlaylist(
          name: _name(),
          description: _description,
        );
        await client.addItems(created.id, ids);
        return created;
      case MusicProvider.appleMusic:
        final id = await ref
            .read(appleMusicApiClientProvider)!
            .createLibraryPlaylist(
              name: _name(),
              description: _description,
              songIds: ids,
            );
        return (id: id, url: null);
      case MusicProvider.demo:
        throw const UnsupportedPlatformFailure('Demo songs cannot be saved.');
    }
  }

  Future<void> _append(MusicProvider provider, String id, List<String> ids) =>
      switch (provider) {
        MusicProvider.spotify =>
          ref.read(spotifyApiClientProvider)!.addItems(id, ids),
        MusicProvider.appleMusic =>
          ref.read(appleMusicApiClientProvider)!.addToLibraryPlaylist(id, ids),
        MusicProvider.demo => throw const UnsupportedPlatformFailure(
          'Demo songs cannot be saved.',
        ),
      };

  static String _serviceName(MusicProvider p) => switch (p) {
    MusicProvider.spotify => 'Spotify',
    MusicProvider.appleMusic => 'Apple Music',
    MusicProvider.demo => 'the demo',
  };

  String _name() {
    final moods = [
      for (final m in Mood.values)
        if (ref.read(moodControllerProvider).moods.contains(m) &&
            m != Mood.other)
          m.label,
    ];
    return moods.isEmpty
        ? 'MoodScape'
        : 'MoodScape · ${moods.take(3).join(', ')}';
  }
}
