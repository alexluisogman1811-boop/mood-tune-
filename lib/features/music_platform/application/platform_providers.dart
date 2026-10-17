import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../../core/configuration/config_provider.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../services/spotify/spotify_api_client.dart';
import '../../../services/spotify/spotify_auth_service.dart';
import '../../../services/spotify/spotify_tokens.dart';

enum MusicPlatform {
  spotify('Spotify'),
  appleMusic('Apple Music');

  const MusicPlatform(this.label);
  final String label;
}

/// Which service the user prefers. Stored separately from any auth state.
final selectedPlatformProvider =
    NotifierProvider<SelectedPlatform, MusicPlatform?>(SelectedPlatform.new);

class SelectedPlatform extends Notifier<MusicPlatform?> {
  static const _key = 'music_platform.selected';

  @override
  MusicPlatform? build() {
    final name = ref.read(sharedPreferencesProvider).getString(_key);
    for (final p in MusicPlatform.values) {
      if (p.name == name) return p;
    }
    return null;
  }

  Future<void> select(MusicPlatform? platform) async {
    state = platform;
    final prefs = ref.read(sharedPreferencesProvider);
    if (platform == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, platform.name);
    }
  }
}

// ---- Spotify wiring ------------------------------------------------------

final webAuthLauncherProvider = Provider<WebAuthLauncher>(
  (ref) =>
      (url, scheme) => FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: scheme,
      ),
);

final spotifyTokenStoreProvider = Provider<SpotifyTokenStore>(
  (ref) => SpotifyTokenStore(ref.watch(secureStorageProvider)),
);

/// Null when no Spotify client id / redirect URI is configured.
final spotifyAuthServiceProvider = Provider<SpotifyAuthService?>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.hasSpotify) return null;
  return SpotifyAuthService(
    clientId: config.spotifyClientId,
    redirectUri: config.spotifyRedirectUri,
    dio: ref.watch(dioProvider),
    store: ref.watch(spotifyTokenStoreProvider),
    launcher: ref.watch(webAuthLauncherProvider),
  );
});

final spotifyApiClientProvider = Provider<SpotifyApiClient?>((ref) {
  final auth = ref.watch(spotifyAuthServiceProvider);
  if (auth == null) return null;
  return SpotifyApiClient(dio: ref.watch(dioProvider), auth: auth);
});

class SpotifyConnection {
  const SpotifyConnection({
    required this.configured,
    required this.connected,
    this.displayName,
  });

  final bool configured;
  final bool connected;
  final String? displayName;
}

final spotifyConnectionProvider =
    AsyncNotifierProvider<SpotifyConnectionController, SpotifyConnection>(
      SpotifyConnectionController.new,
    );

class SpotifyConnectionController extends AsyncNotifier<SpotifyConnection> {
  @override
  Future<SpotifyConnection> build() async {
    final auth = ref.watch(spotifyAuthServiceProvider);
    if (auth == null) {
      return const SpotifyConnection(configured: false, connected: false);
    }
    return SpotifyConnection(
      configured: true,
      connected: await auth.isConnected(),
    );
  }

  /// Returns a user-facing error message, or null on success/cancel.
  Future<String?> connect() async {
    final auth = ref.read(spotifyAuthServiceProvider);
    if (auth == null) return 'Spotify is not configured for this build.';
    state = const AsyncLoading();
    try {
      await auth.connect();
    } on AuthCancelledFailure {
      state = AsyncData(await build());
      return null;
    } on AppFailure catch (e) {
      state = AsyncData(await build());
      return e.message;
    }
    String? name;
    try {
      name = await ref.read(spotifyApiClientProvider)?.displayName();
    } on AppFailure {
      // Name is cosmetic; the connection itself succeeded.
    }
    state = AsyncData(
      SpotifyConnection(configured: true, connected: true, displayName: name),
    );
    return null;
  }

  Future<void> disconnect() async {
    await ref.read(spotifyAuthServiceProvider)?.disconnect();
    state = AsyncData(await build());
  }
}
