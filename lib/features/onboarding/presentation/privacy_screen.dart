import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../shared/widgets/gradient_background.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _points = [
    (
      'What the photo is for',
      'We look at the environment only: lighting, weather-like cues, '
          'setting, colours and overall atmosphere. We never try to read '
          'emotions from faces or people.',
    ),
    (
      'Your feelings come from you',
      'Your mood is whatever you tell us. Free-text descriptions are optional '
          'and you never need to share sensitive details.',
    ),
    (
      'Uploads need consent',
      'If remote AI analysis is enabled, we ask before sending a photo. You '
          'can decline and still get recommendations from your mood alone.',
    ),
    (
      'Nothing is kept',
      'Photos are resized, stripped of location data and kept in memory only '
          '— MoodScape never saves them to storage.',
    ),
    (
      'You stay in control',
      'Settings lets you change upload consent, disconnect music services '
          'and clear everything MoodScape stores on this device.',
    ),
    (
      'Music accounts',
      'Spotify and Apple Music tokens are kept in the device secure storage '
          'and can be removed at any time from Settings.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(context.tr('Privacy'))),
      body: GradientBackground(
        child: SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: _points.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final (title, body) = _points[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(title),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(context.tr(body), style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
