import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../data/track_links.dart';
import '../domain/playlist_export.dart';
import '../domain/track.dart';

/// "Make this a Spotify playlist" without Spotify API access: copy the song
/// list, then let a free transfer tool create the playlist in the user's
/// own Spotify account (free accounts work).
Future<void> showExportSheet(BuildContext context, List<Track> tracks) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ExportSheet(tracks: tracks),
    );

class _ExportSheet extends ConsumerWidget {
  const _ExportSheet({required this.tracks});

  final List<Track> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);

    Widget step(int n, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 12, child: Text('$n')),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Make this a Spotify playlist'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('Works with free Spotify. Takes about a minute.'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            step(
              1,
              context.tr('Tap "Copy song list" ({count} songs).', {
                'count': tracks.length,
              }),
            ),
            step(
              2,
              context.tr(
                'Tap "Open TuneMyMusic", choose "Free text" as the source and '
                'paste the list.',
              ),
            ),
            step(
              3,
              context.tr(
                'Choose Spotify as the destination, sign in, and start the '
                'transfer. The playlist appears in your Spotify.',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () async {
                final copied = context.tr('Copied {count} songs.', {
                  'count': tracks.length,
                });
                await Clipboard.setData(
                  ClipboardData(text: PlaylistExport.asText(tracks)),
                );
                messenger.showSnackBar(SnackBar(content: Text(copied)));
              },
              icon: const Icon(Icons.copy),
              label: Text(context.tr('Copy song list')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () async {
                final failed = context.tr('Could not open the link.');
                final ok = await ref.read(urlOpenerProvider)(
                  PlaylistExport.transferToolUrl,
                );
                if (!ok) {
                  messenger.showSnackBar(SnackBar(content: Text(failed)));
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: Text(context.tr('Open TuneMyMusic')),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr(
                'TuneMyMusic is a separate free service (up to 500 songs). You '
                'sign in to Spotify on their site; MoodScape never sees your '
                'Spotify password.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
