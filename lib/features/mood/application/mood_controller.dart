import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/mood.dart';

final moodControllerProvider = NotifierProvider<MoodController, MoodInput>(
  MoodController.new,
);

class MoodController extends Notifier<MoodInput> {
  @override
  MoodInput build() => const MoodInput();

  void toggle(Mood mood) {
    final next = {...state.moods};
    if (!next.remove(mood)) next.add(mood);
    state = state.copyWith(moods: next);
  }

  /// Pass null to clear. Out-of-range values are clamped.
  void setIntensity(int? value) {
    state = state.copyWith(
      intensity: () =>
          value?.clamp(MoodInput.minIntensity, MoodInput.maxIntensity),
    );
  }

  void setDescription(String text) {
    var trimmed = text.trim();
    if (trimmed.length > MoodInput.maxDescriptionLength) {
      trimmed = trimmed.substring(0, MoodInput.maxDescriptionLength);
    }
    state = state.copyWith(description: () => trimmed.isEmpty ? null : trimmed);
  }

  void reset() => state = const MoodInput();
}
