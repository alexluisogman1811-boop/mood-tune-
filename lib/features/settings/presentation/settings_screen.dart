import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/configuration/config_provider.dart';
import '../../../core/l10n/app_language.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/privacy/photo_consent.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../music_platform/application/apple_music_providers.dart';
import '../../music_platform/application/platform_providers.dart';
import '../../recommendations/application/disliked_tracks.dart';
import '../../recommendations/application/recommendations_controller.dart';
import '../application/data_controls.dart';
import '../application/theme_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Text(
        context.tr(title),
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(context.tr('Settings'))),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              section('Language'),
              const _LanguagePicker(),
              section('Appearance'),
              const _ThemePicker(),
              section('Music services'),
              const _ServicesCard(),
              section('Privacy'),
              const _PrivacyCard(),
              section('Your data'),
              const _DataCard(),
              section('About'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.tr(
                      'Match scores estimate how well a song fits what you told '
                      'us and what the photo shows. They are not a scientific '
                      'measurement of emotion. Photos are used to describe the '
                      'environment only.',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguagePicker extends ConsumerWidget {
  const _LanguagePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appLanguageProvider);
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<AppLanguage>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: AppLanguage.system,
            label: Text(context.tr('System')),
          ),
          // Each language is named in its own words.
          const ButtonSegment(
            value: AppLanguage.english,
            label: Text('English'),
          ),
          const ButtonSegment(value: AppLanguage.thai, label: Text('ไทย')),
        ],
        selected: {language},
        onSelectionChanged: (s) =>
            ref.read(appLanguageProvider.notifier).set(s.first),
      ),
    );
  }
}

class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: ThemeMode.dark, label: Text(context.tr('Dark'))),
          ButtonSegment(
            value: ThemeMode.light,
            label: Text(context.tr('Light')),
          ),
          ButtonSegment(
            value: ThemeMode.system,
            label: Text(context.tr('System')),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (s) =>
            ref.read(themeModeProvider.notifier).set(s.first),
      ),
    );
  }
}

class _ServicesCard extends ConsumerWidget {
  const _ServicesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotify = ref.watch(spotifyConnectionProvider).value;
    final apple = ref.watch(appleMusicConnectionProvider).value;
    final selected = ref.watch(selectedPlatformProvider);

    final spotifyStatus = switch (spotify) {
      null => 'Checking…',
      SpotifyConnection(configured: false) => 'Not set up in this build',
      SpotifyConnection(connected: true) => 'Connected',
      _ => 'Not connected',
    };
    final appleStatus = switch (apple) {
      null => 'Checking…',
      AppleMusicConnection(catalogAvailable: false) =>
        'Not set up in this build',
      AppleMusicConnection(authorized: true) => 'Library connected',
      AppleMusicConnection(librarySupported: false) => 'Catalogue only',
      _ => 'Library not connected',
    };

    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(context.tr('Preferred service')),
            subtitle: Text(
              context.tr(selected?.label ?? 'None (demo catalogue)'),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.platform),
          ),
          ListTile(
            title: Text(context.tr('Spotify')),
            subtitle: Text(context.tr(spotifyStatus)),
            trailing: spotify?.connected == true
                ? TextButton(
                    onPressed: () => ref
                        .read(spotifyConnectionProvider.notifier)
                        .disconnect(),
                    child: Text(context.tr('Disconnect')),
                  )
                : null,
          ),
          ListTile(
            title: Text(context.tr('Apple Music')),
            subtitle: Text(context.tr(appleStatus)),
            trailing: apple?.authorized == true
                ? TextButton(
                    onPressed: () => ref
                        .read(appleMusicConnectionProvider.notifier)
                        .disconnect(),
                    child: Text(context.tr('Disconnect')),
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              context.tr(
                'Disconnecting removes tokens from this device. To revoke '
                'access fully, use spotify.com/account/apps or iOS Settings › '
                'Privacy & Security › Media & Apple Music.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

enum _UploadChoice {
  ask('Ask each time'),
  allow('Allow'),
  never('Never');

  const _UploadChoice(this.label);
  final String label;

  static _UploadChoice from(bool? consent) => switch (consent) {
    null => ask,
    true => allow,
    false => never,
  };

  bool? get consent => switch (this) {
    ask => null,
    allow => true,
    never => false,
  };
}

class _PrivacyCard extends ConsumerWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(photoUploadConsentProvider);
    final backend = ref.watch(appConfigProvider).hasAnalysisBackend;
    final small = Theme.of(context).textTheme.bodySmall;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('Upload photos for AI analysis')),
            const SizedBox(height: 4),
            Text(
              context.tr(
                backend
                    ? 'Photos are resized, stripped of location data and sent '
                          'over HTTPS only with your consent.'
                    : 'No AI service is configured, so photos never leave '
                          'this device.',
              ),
              style: small,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<_UploadChoice>(
                showSelectedIcon: false,
                segments: [
                  for (final c in _UploadChoice.values)
                    ButtonSegment(value: c, label: Text(context.tr(c.label))),
                ],
                selected: {_UploadChoice.from(consent)},
                onSelectionChanged: (s) => ref
                    .read(photoUploadConsentProvider.notifier)
                    .set(s.first.consent),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.push(AppRoutes.privacy),
              child: Text(context.tr('How MoodScape handles your data')),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataCard extends ConsumerWidget {
  const _DataCard();

  Future<void> _confirmAndClear(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final cleared = context.tr('All MoodScape data was cleared.');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Clear all data?')),
        content: Text(
          context.tr(
            'This removes your preferences, privacy choices, music service '
            'connections and the current photo and mood from this device. '
            'It cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('Clear data')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(dataControlsProvider).clearAll();
    messenger.showSnackBar(SnackBar(content: Text(cleared)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disliked = ref.watch(dislikedTracksProvider).length;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.thumb_down_alt_outlined),
            title: Text(context.tr('Forget disliked songs')),
            subtitle: Text(switch (disliked) {
              0 => context.tr('No songs marked "Not for me"'),
              1 => context.tr('1 song hidden from recommendations'),
              _ => context.tr('{count} songs hidden from recommendations', {
                'count': disliked,
              }),
            }),
            enabled: disliked > 0,
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final done = context.tr(
                'Disliked songs can be recommended again.',
              );
              await ref.read(dislikedTracksProvider.notifier).clear();
              ref.invalidate(recommendationsProvider);
              messenger.showSnackBar(SnackBar(content: Text(done)));
            },
          ),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(context.tr('Clear all data')),
            subtitle: Text(
              context.tr(
                'Preferences, consent choices, tokens, disliked songs, photo '
                'and mood',
              ),
            ),
            onTap: () => _confirmAndClear(context, ref),
          ),
        ],
      ),
    );
  }
}
