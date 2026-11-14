import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/music_preferences.dart';

/// One band or artist in the built-in catalogue, for the picker.
class CatalogArtist {
  const CatalogArtist({required this.name, required this.songs, this.language});

  final String name;

  /// How many songs the catalogue has by them.
  final int songs;

  /// The language most of their songs are sung in; null for instrumental
  /// or mixed artists.
  final MusicLanguage? language;
}

/// The index written beside the catalogue by `tool/build_catalog.py`. It is
/// much smaller than the catalogue, so the picker opens quickly.
const artistsAssetPath = 'assets/demo/artists.json';

/// Lets tests supply their own asset bundle.
final assetBundleProvider = Provider<AssetBundle>((ref) => rootBundle);

/// Bands in the catalogue, the ones with the most songs first. An
/// unreadable file gives an empty list: the picker then just takes typing.
final artistCatalogProvider = FutureProvider<List<CatalogArtist>>((ref) async {
  final raw = await ref.read(assetBundleProvider).loadString(artistsAssetPath);
  return parseArtists(raw);
});

/// Skips malformed entries rather than losing the whole list.
List<CatalogArtist> parseArtists(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map || decoded['artists'] is! List) return const [];
  final out = <CatalogArtist>[];
  for (final entry in decoded['artists'] as List) {
    if (entry is! Map) continue;
    final name = entry['n'];
    if (name is! String || name.trim().isEmpty) continue;
    out.add(
      CatalogArtist(
        name: name.trim(),
        songs: entry['c'] is num ? (entry['c'] as num).toInt() : 0,
        language: MusicLanguage.values
            .where((l) => l.name == entry['l'])
            .firstOrNull,
      ),
    );
  }
  return out;
}

/// Bands to offer for [query]. With no query it suggests the best-known
/// bands in the languages the user chose; otherwise it searches every name.
/// Already [picked] bands are left out.
List<CatalogArtist> suggestArtists(
  List<CatalogArtist> all, {
  required String query,
  required Set<String> picked,
  Set<MusicLanguage> languages = const {},
  int limit = 12,
}) {
  final pickedKeys = {for (final p in picked) MusicPreferences.artistKey(p)};
  final q = query.trim().toLowerCase();
  final matches = [
    for (final a in all)
      if (!pickedKeys.contains(MusicPreferences.artistKey(a.name)) &&
          (q.isEmpty
              ? (languages.isEmpty || languages.contains(a.language))
              : a.name.toLowerCase().contains(q)))
        a,
  ];
  if (q.isEmpty) return matches.take(limit).toList(growable: false);
  // A name that starts with what was typed is the likelier one.
  matches.sort((a, b) {
    final byStart =
        (b.name.toLowerCase().startsWith(q) ? 1 : 0) -
        (a.name.toLowerCase().startsWith(q) ? 1 : 0);
    return byStart != 0 ? byStart : b.songs.compareTo(a.songs);
  });
  return matches.take(limit).toList(growable: false);
}
