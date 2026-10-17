import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../mood/application/mood_controller.dart';
import '../../mood/domain/mood.dart';
import '../../music_platform/application/apple_music_providers.dart';
import '../../music_platform/application/platform_providers.dart';
import '../domain/track.dart';

/// Outcome of a playlist action, for a snackbar.
class PlaylistResult {
  const PlaylistResult(this.message, {this.url});
  final String message;
  final Uri? url;
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
        'Saved ${ids.length} songs to ${_serviceName(provider)}.',
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
        'Added to your MoodScape playlist on ${_serviceName(provider)}.',
      );
    } on AppFailure catch (e) {
      return PlaylistResult(e.message);
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
