import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/privacy/photo_consent.dart';
import '../../../core/storage/storage_providers.dart';
import '../../atmosphere/application/analysis_controller.dart';
import '../../camera/application/captured_photo_controller.dart';
import '../../mood/application/mood_controller.dart';
import '../../music_platform/application/apple_music_providers.dart';
import '../../music_platform/application/platform_providers.dart';
import '../../preferences/application/preferences_controller.dart';
import '../../recommendations/application/disliked_tracks.dart';
import '../../recommendations/application/playlist_controller.dart';
import '../../recommendations/application/recommendations_controller.dart';
import 'theme_controller.dart';

final dataControlsProvider = Provider<DataControls>(DataControls.new);

/// Removes everything MoodScape keeps on this device.
class DataControls {
  DataControls(this._ref);
  final Ref _ref;

  /// Deletes stored preferences, consent choices and music-service tokens,
  /// and drops the in-memory photo, analysis and mood. Access granted on
  /// Spotify or Apple's side must be revoked there (see Settings).
  Future<void> clearAll() async {
    await _ref.read(sharedPreferencesProvider).clear();
    await _ref.read(secureStorageProvider).deleteAll();

    _ref.read(capturedPhotoProvider.notifier).clear();
    _ref.read(analysisControllerProvider.notifier).reset();
    _ref.read(moodControllerProvider.notifier).reset();

    // Re-read everything from the now-empty storage.
    _ref
      ..invalidate(musicPreferencesProvider)
      ..invalidate(photoUploadConsentProvider)
      ..invalidate(selectedPlatformProvider)
      ..invalidate(themeModeProvider)
      ..invalidate(spotifyConnectionProvider)
      ..invalidate(appleMusicConnectionProvider)
      ..invalidate(playlistControllerProvider)
      ..invalidate(dislikedTracksProvider)
      ..invalidate(resultFilterProvider)
      ..invalidate(recommendationsProvider);
  }
}
