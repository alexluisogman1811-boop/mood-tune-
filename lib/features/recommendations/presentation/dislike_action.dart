import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../application/playlist_controller.dart';
import '../application/recommendations_controller.dart';

/// "Not for me": removes the song, shows what replaced it, keeps a saved
/// playlist in step, and offers Undo. Shared by the results list and the
/// track details screen.
Future<void> dislikeTrack(
  BuildContext context,
  WidgetRef ref,
  String trackId,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final recs = ref.read(recommendationsProvider.notifier);
  final playlists = ref.read(playlistControllerProvider.notifier);

  final outcome = await recs.dislike(trackId);
  if (outcome == null) return;
  final sync = await playlists.swap(
    removed: outcome.removed.track,
    added: outcome.replacement?.track,
  );

  final removedTitle = outcome.removed.track.title;
  final replacement = outcome.replacement;
  final text = [
    replacement == null
        ? 'Removed “$removedTitle”. No other songs left to suggest.'
        : 'Removed “$removedTitle” — added “${replacement.track.title}”.',
    ?sync?.message,
  ].join(' ');

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await recs.undoDislike(outcome);
            await playlists.swap(
              removed: replacement?.track,
              added: outcome.removed.track,
            );
          },
        ),
      ),
    );
}
