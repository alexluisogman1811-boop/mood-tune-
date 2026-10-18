import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';

/// Songs the user marked "Not for me". They are never recommended again
/// (until the user forgets them in Settings or clears all data).
final dislikedTracksProvider =
    NotifierProvider<DislikedTracksController, Set<String>>(
      DislikedTracksController.new,
    );

class DislikedTracksController extends Notifier<Set<String>> {
  static const storageKey = 'recommendations.disliked.v1';

  @override
  Set<String> build() =>
      (ref.read(sharedPreferencesProvider).getStringList(storageKey) ?? [])
          .toSet();

  Future<void> add(String trackId) => _save({...state, trackId});

  Future<void> remove(String trackId) => _save({...state}..remove(trackId));

  Future<void> clear() => _save(const {});

  Future<void> _save(Set<String> next) async {
    state = next;
    final prefs = ref.read(sharedPreferencesProvider);
    if (next.isEmpty) {
      await prefs.remove(storageKey);
    } else {
      await prefs.setStringList(storageKey, next.toList());
    }
  }
}
