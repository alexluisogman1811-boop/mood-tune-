import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/preferences/application/preferences_controller.dart';
import 'package:moodscape/features/preferences/domain/music_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults mean "skipped": no taste preferences, no energy', () {
    const p = MusicPreferences();
    expect(p.hasTastePreferences, isFalse);
    expect(p.energy, isNull);
    expect(p.allowExplicit, isTrue);
    expect(p.playlistLength, 20);
  });

  test('JSON round-trip preserves every field', () {
    const p = MusicPreferences(
      genres: {Genre.jazz, Genre.lofi},
      languages: {MusicLanguage.korean},
      vocal: VocalPreference.instrumental,
      discovery: DiscoveryPreference.discover,
      energy: EnergyPreference.relaxing,
      allowExplicit: false,
      playlistLength: 30,
    );
    final back = MusicPreferences.fromJson(jsonDecode(jsonEncode(p.toJson())));
    expect(back.toJson(), p.toJson());
  });

  test('bad stored data falls back field by field', () {
    final p = MusicPreferences.fromJson({
      'genres': ['jazz', 'polka', 3],
      'vocal': 'shouting',
      'playlistLength': 999,
      'allowExplicit': 'yes',
    });
    expect(p.genres, {Genre.jazz});
    expect(p.vocal, VocalPreference.any);
    expect(p.playlistLength, 20);
    expect(p.allowExplicit, isTrue);
    expect(
      MusicPreferences.fromJson('nope').toJson(),
      const MusicPreferences().toJson(),
    );
  });

  test(
    'controller persists and restores, and survives corrupt storage',
    () async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      var c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
      );
      await c
          .read(musicPreferencesProvider.notifier)
          .save(const MusicPreferences(genres: {Genre.rock}));
      c.dispose();

      c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
      );
      expect(c.read(musicPreferencesProvider).genres, {Genre.rock});
      c.dispose();

      await sp.setString(MusicPreferencesController.storageKey, '{not json');
      c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
      );
      expect(c.read(musicPreferencesProvider).genres, isEmpty);
      c.dispose();
    },
  );
}
