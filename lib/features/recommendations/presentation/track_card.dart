import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../shared/widgets/artwork.dart';
import '../domain/match_scorer.dart';

class TrackCard extends StatelessWidget {
  const TrackCard({
    required this.match,
    required this.onTap,
    this.onDislike,
    super.key,
  });

  final TrackMatch match;
  final VoidCallback onTap;

  /// "Not for me": removes the song and suggests another.
  final VoidCallback? onDislike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = match.track;
    final subtitle = [t.artist, ?t.album].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Artwork(url: t.artworkUrl, seed: t.id),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      match.explanationIn(context.languageCode),
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  ScoreBadge(score: match.score),
                  if (onDislike case final dislike?)
                    IconButton(
                      tooltip: context.tr('Not for me'),
                      onPressed: dislike,
                      icon: const Icon(Icons.thumb_down_alt_outlined),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScoreBadge extends StatelessWidget {
  const ScoreBadge({required this.score, this.size = 48, super.key});

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: context.tr('Match score {score} out of 100', {'score': score}),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 3,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            Text(
              '$score',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
