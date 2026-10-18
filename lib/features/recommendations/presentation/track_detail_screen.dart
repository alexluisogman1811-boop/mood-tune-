import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/artwork.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../application/playlist_controller.dart';
import '../application/recommendations_controller.dart';
import '../data/track_links.dart';
import '../domain/match_scorer.dart';
import '../domain/track.dart';
import 'preview_player.dart';
import 'track_card.dart';

class TrackDetailScreen extends ConsumerWidget {
  const TrackDetailScreen({required this.trackId, super.key});

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = ref.watch(recommendationsProvider).value?.byId(trackId);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(),
      body: GradientBackground(
        child: SafeArea(
          child: match == null
              ? const Center(
                  child: Text('This song is no longer in your list.'),
                )
              : _Details(match: match),
        ),
      ),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.match});
  final TrackMatch match;

  Future<void> _open(BuildContext context, WidgetRef ref, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(urlOpenerProvider)(uri);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = match.track;
    final meta = [
      ?t.album,
      if (t.releaseYear != null) '${t.releaseYear}',
    ].join(' · ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        Center(
          child: Artwork(url: t.artworkUrl, seed: t.id, size: 200, radius: 24),
        ),
        const SizedBox(height: 20),
        Text(t.title, style: theme.textTheme.headlineSmall),
        Text(t.artist, style: theme.textTheme.titleMedium),
        if (meta.isNotEmpty)
          Text(
            meta,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (t.isExplicit ?? false)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Explicit'),
          ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ScoreBadge(score: match.score, size: 56),
                    const SizedBox(width: 16),
                    Expanded(child: Text(match.explanation)),
                  ],
                ),
                const SizedBox(height: 16),
                for (final c in MatchComponent.values)
                  _ComponentRow(
                    component: c,
                    value: match.components[c],
                    weight: match.weights[c],
                  ),
                const SizedBox(height: 8),
                Text(
                  'Missing information is left out and its weight shared by '
                  'the rest. This is an estimate, not a measure of emotion.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (t.previewUrl case final preview?)
          PreviewPlayer(
            url: preview,
            onOpenExternally: () => _open(context, ref, preview),
          )
        else
          Text(
            t.provider == MusicProvider.demo
                ? 'Previews are not available in demo mode.'
                : 'No preview is available for this song.',
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _open(context, ref, TrackLinks.spotify(t)),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open in Spotify'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _open(context, ref, TrackLinks.appleMusic(t)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open in Apple Music'),
        ),
        const SizedBox(height: 8),
        _AddToPlaylistButton(track: t),
      ],
    );
  }
}

class _AddToPlaylistButton extends ConsumerStatefulWidget {
  const _AddToPlaylistButton({required this.track});
  final Track track;

  @override
  ConsumerState<_AddToPlaylistButton> createState() =>
      _AddToPlaylistButtonState();
}

class _AddToPlaylistButtonState extends ConsumerState<_AddToPlaylistButton> {
  bool _busy = false;

  Future<void> _add() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(playlistControllerProvider.notifier)
        .add(widget.track);
    if (mounted) setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.track.provider;
    final supported = ref.watch(canSavePlaylistProvider(provider));
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      onPressed: supported && !_busy ? _add : null,
      icon: const Icon(Icons.playlist_add),
      label: Text(switch ((provider, supported)) {
        (MusicProvider.spotify, true) => 'Add to Spotify playlist',
        (MusicProvider.appleMusic, true) => 'Add to Apple Music playlist',
        (MusicProvider.demo, _) => 'Demo songs cannot be added to playlists',
        _ =>
          'Add to playlist — connect ${provider == MusicProvider.spotify ? 'Spotify' : 'Apple Music'} first',
      }),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({
    required this.component,
    required this.value,
    required this.weight,
  });

  final MatchComponent component;
  final double? value;
  final double? weight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = value;
    final w = weight;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(component.label)),
              Text(
                v == null || w == null
                    ? 'not available'
                    : '${v.round()} · weight ${(w * 100).round()}%',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: v == null ? 0 : v / 100,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}
