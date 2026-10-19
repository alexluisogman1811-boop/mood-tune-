import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../services/image_analysis/scene_features.dart';

/// Read-only summary of what the analysis found in the scene.
class SceneSummaryCard extends StatelessWidget {
  const SceneSummaryCard({required this.features, super.key});

  final SceneFeatures features;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = features;
    String label(Enum e) =>
        context.tr(e.name[0].toUpperCase() + e.name.substring(1));

    final tags = [
      if (f.setting != SceneSetting.unknown) label(f.setting),
      if (f.lighting != SceneLighting.unknown)
        context.tr('{light} light', {'light': label(f.lighting)}),
      for (final c in f.cues) label(c),
      for (final a in f.atmosphere) label(a),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Your atmosphere'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('{source} · confidence {percent}%', {
                'source': context.tr(f.source.label),
                'percent': (f.confidence * 100).round(),
              }),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (tags.isEmpty)
              Text(context.tr('No strong atmosphere detected.'))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final t in tags) Chip(label: Text(t))],
              ),
            const SizedBox(height: 16),
            Text(context.tr('Scene energy'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Semantics(
              label: context.tr('Scene energy {energy} out of 100', {
                'energy': f.energy,
              }),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: f.energy / 100,
                  minHeight: 8,
                ),
              ),
            ),
            if (f.palette.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                context.tr('Colour palette'),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final hex in f.palette)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(
                            int.parse(hex.substring(1), radix: 16) | 0xFF000000,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
