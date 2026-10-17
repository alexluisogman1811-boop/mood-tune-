import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../application/apple_music_providers.dart';
import '../application/platform_providers.dart';

class PlatformScreen extends ConsumerWidget {
  const PlatformScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPlatformProvider);
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Music platform'),
        actions: [
          TextButton(
            onPressed: () => context.push(AppRoutes.analysis),
            child: const Text('Skip for now'),
          ),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Text(
                'Where do you listen?',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Without a connected service, MoodScape uses its demo '
                'catalogue.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              _PlatformCard(
                platform: MusicPlatform.spotify,
                icon: Icons.graphic_eq,
                selected: selected == MusicPlatform.spotify,
                child: const _SpotifyStatus(),
              ),
              const SizedBox(height: 12),
              _PlatformCard(
                platform: MusicPlatform.appleMusic,
                icon: Icons.music_note,
                selected: selected == MusicPlatform.appleMusic,
                child: const _AppleMusicStatus(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.push(AppRoutes.analysis),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformCard extends ConsumerWidget {
  const _PlatformCard({
    required this.platform,
    required this.icon,
    required this.selected,
    required this.child,
  });

  final MusicPlatform platform;
  final IconData icon;
  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? scheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              selected: selected,
              onTap: () =>
                  ref.read(selectedPlatformProvider.notifier).select(platform),
              leading: Icon(icon, size: 32),
              title: Text(platform.label),
              trailing: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _SpotifyStatus extends ConsumerWidget {
  const _SpotifyStatus();

  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(selectedPlatformProvider.notifier)
        .select(MusicPlatform.spotify);
    final error = await ref.read(spotifyConnectionProvider.notifier).connect();
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(spotifyConnectionProvider);
    return switch (conn) {
      AsyncData(:final value) when !value.configured => const _SetupHelp(),
      AsyncData(:final value) when value.connected => Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.displayName == null
                  ? 'Connected'
                  : 'Connected as ${value.displayName}',
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(spotifyConnectionProvider.notifier).disconnect(),
            child: const Text('Disconnect'),
          ),
        ],
      ),
      AsyncData() => Row(
        children: [
          const Expanded(child: Text('Not connected')),
          FilledButton.tonal(
            onPressed: () => _connect(context, ref),
            child: const Text('Connect'),
          ),
        ],
      ),
      AsyncError() => const Text('Could not read the Spotify connection.'),
      _ => const LinearProgressIndicator(),
    };
  }
}

class _SetupHelp extends StatelessWidget {
  const _SetupHelp();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Spotify is not set up in this build, so results use the demo '
          'catalogue.',
        ),
        const SizedBox(height: 8),
        Text(
          'To enable it: create an app at developer.spotify.com, add the '
          'redirect URI moodscape://spotify-callback, then run with '
          '--dart-define-from-file=config/dev.json containing '
          'SPOTIFY_CLIENT_ID and SPOTIFY_REDIRECT_URI. In Development Mode '
          'only allow-listed Spotify accounts can sign in.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _AppleMusicStatus extends ConsumerWidget {
  const _AppleMusicStatus();

  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(selectedPlatformProvider.notifier)
        .select(MusicPlatform.appleMusic);
    final error = await ref
        .read(appleMusicConnectionProvider.notifier)
        .connect();
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final small = Theme.of(context).textTheme.bodySmall;
    return switch (ref.watch(appleMusicConnectionProvider)) {
      AsyncData(:final value) when !value.catalogAvailable => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Apple Music is not set up in this build, so results use the '
            'demo catalogue.',
          ),
          const SizedBox(height: 8),
          Text(
            'iOS: enable the MusicKit App Service for the app\'s bundle ID in '
            'the Apple Developer portal. Android: run a token service and set '
            'APPLE_MUSIC_DEVELOPER_TOKEN_URL (HTTPS).',
            style: small,
          ),
        ],
      ),
      AsyncData(:final value) when !value.librarySupported => Text(
        'Catalogue search is available. Saving playlists to your Apple Music '
        'library needs the iOS app; here you can open songs in Apple Music.',
        style: small,
      ),
      AsyncData(:final value) when value.authorized => Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.canPlayCatalog == false
                  ? 'Connected — no active subscription, so saving to your '
                        'library may fail'
                  : 'Connected',
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(appleMusicConnectionProvider.notifier).disconnect(),
            child: const Text('Disconnect'),
          ),
        ],
      ),
      AsyncData() => Row(
        children: [
          const Expanded(
            child: Text('Catalogue ready · library not connected'),
          ),
          FilledButton.tonal(
            onPressed: () => _connect(context, ref),
            child: const Text('Connect'),
          ),
        ],
      ),
      AsyncError() => const Text('Could not read the Apple Music connection.'),
      _ => const LinearProgressIndicator(),
    };
  }
}
