import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/configuration/config_provider.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../services/apple_music/apple_music_api_client.dart';
import '../../../services/apple_music/apple_music_tokens.dart';
import '../../../services/apple_music/musickit_bridge.dart';

final musicKitBridgeProvider = Provider<MusicKitBridge>(
  (ref) => const MethodChannelMusicKitBridge(),
);

/// Two-letter storefront guessed from the device region (e.g. "us").
final deviceStorefrontProvider = Provider<String>((ref) {
  final code = PlatformDispatcher.instance.locale.countryCode?.toLowerCase();
  return code != null && AppleMusicApiClient.isValidStorefront(code)
      ? code
      : 'us';
});

/// Null when neither native MusicKit nor a token backend is available.
final appleDeveloperTokenProvider = Provider<AppleDeveloperTokenProvider?>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  final provider = AppleDeveloperTokenProvider(
    native: ref.watch(musicKitBridgeProvider),
    dio: ref.watch(dioProvider),
    backendUrl: config.hasAppleMusicTokenService
        ? Uri.parse(config.appleMusicDeveloperTokenUrl)
        : null,
  );
  return provider.isAvailable ? provider : null;
});

final appleMusicUserTokenStoreProvider = Provider<AppleMusicUserTokenStore>(
  (ref) => AppleMusicUserTokenStore(ref.watch(secureStorageProvider)),
);

final appleMusicApiClientProvider = Provider<AppleMusicApiClient?>((ref) {
  final dev = ref.watch(appleDeveloperTokenProvider);
  if (dev == null) return null;
  return AppleMusicApiClient(
    dio: ref.watch(dioProvider),
    developerTokens: dev,
    userTokens: ref.watch(appleMusicUserTokenStoreProvider),
  );
});

class AppleMusicConnection {
  const AppleMusicConnection({
    required this.catalogAvailable,
    required this.librarySupported,
    required this.authorized,
    this.canPlayCatalog,
  });

  /// Catalogue search works (developer token obtainable).
  final bool catalogAvailable;

  /// This platform can authorise library access (iOS only for now).
  final bool librarySupported;

  /// A Music User Token is stored.
  final bool authorized;

  /// Subscription status when known.
  final bool? canPlayCatalog;
}

final appleMusicConnectionProvider =
    AsyncNotifierProvider<AppleMusicConnectionController, AppleMusicConnection>(
      AppleMusicConnectionController.new,
    );

class AppleMusicConnectionController
    extends AsyncNotifier<AppleMusicConnection> {
  @override
  Future<AppleMusicConnection> build() async {
    final available = ref.watch(appleDeveloperTokenProvider) != null;
    final native = ref.watch(musicKitBridgeProvider);
    final token = await ref.watch(appleMusicUserTokenStoreProvider).read();
    return AppleMusicConnection(
      catalogAvailable: available,
      librarySupported: native.isSupported,
      authorized: token != null,
    );
  }

  /// Asks for MusicKit permission and stores a Music User Token. Returns a
  /// user-facing message on failure, null on success.
  Future<String?> connect() async {
    final native = ref.read(musicKitBridgeProvider);
    final dev = ref.read(appleDeveloperTokenProvider);
    if (!native.isSupported) {
      return 'Saving to your Apple Music library is only available in the '
          'iOS app. You can still open songs in Apple Music.';
    }
    if (dev == null) return 'Apple Music is not set up for this build.';

    state = const AsyncLoading();
    try {
      final status = await native.requestAuthorization();
      if (status != MusicKitAuthStatus.authorized) {
        state = AsyncData(await build());
        return status == MusicKitAuthStatus.restricted
            ? 'Apple Music access is restricted on this device.'
            : 'Apple Music access was not allowed. You can change this in '
                  'Settings › Privacy & Security › Media & Apple Music.';
      }
      final userToken = await native.userToken(await dev.token());
      await ref.read(appleMusicUserTokenStoreProvider).write(userToken);

      bool? canPlay;
      try {
        canPlay = (await native.subscription()).canPlayCatalog;
      } on AppFailure {
        canPlay = null;
      }
      state = AsyncData(
        AppleMusicConnection(
          catalogAvailable: true,
          librarySupported: true,
          authorized: true,
          canPlayCatalog: canPlay,
        ),
      );
      return null;
    } on AppFailure catch (e) {
      state = AsyncData(await build());
      return e.message;
    }
  }

  /// Removes the stored user token. Users can also revoke access in iOS
  /// Settings.
  Future<void> disconnect() async {
    await ref.read(appleMusicUserTokenStoreProvider).clear();
    state = AsyncData(await build());
  }
}
