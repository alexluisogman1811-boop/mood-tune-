import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../domain/music_preferences.dart';

final musicPreferencesProvider =
    NotifierProvider<MusicPreferencesController, MusicPreferences>(
      MusicPreferencesController.new,
    );

/// Preferences are not sensitive, so they live in SharedPreferences.
class MusicPreferencesController extends Notifier<MusicPreferences> {
  static const storageKey = 'music_preferences.v1';

  @override
  MusicPreferences build() {
    final raw = ref.read(sharedPreferencesProvider).getString(storageKey);
    if (raw == null) return const MusicPreferences();
    try {
      return MusicPreferences.fromJson(jsonDecode(raw));
    } on FormatException {
      return const MusicPreferences();
    }
  }

  Future<void> save(MusicPreferences value) async {
    state = value;
    await ref
        .read(sharedPreferencesProvider)
        .setString(storageKey, jsonEncode(value.toJson()));
  }

  Future<void> reset() async {
    state = const MusicPreferences();
    await ref.read(sharedPreferencesProvider).remove(storageKey);
  }
}
