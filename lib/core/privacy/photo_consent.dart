import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_providers.dart';

/// The user's remembered answer to "may we upload your photo for AI
/// analysis?". Null means "ask me".
final photoUploadConsentProvider = NotifierProvider<PhotoUploadConsent, bool?>(
  PhotoUploadConsent.new,
);

class PhotoUploadConsent extends Notifier<bool?> {
  static const _key = 'privacy.photo_upload_consent';

  @override
  bool? build() => ref.read(sharedPreferencesProvider).getBool(_key);

  Future<void> set(bool? value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (value == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setBool(_key, value);
    }
    state = value;
  }
}
