import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodscape/features/mood/application/mood_controller.dart';
import 'package:moodscape/features/mood/domain/mood.dart';

void main() {
  late ProviderContainer container;
  MoodController controller() =>
      container.read(moodControllerProvider.notifier);
  MoodInput state() => container.read(moodControllerProvider);

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('starts empty and incomplete', () {
    expect(state().moods, isEmpty);
    expect(state().intensity, isNull);
    expect(state().description, isNull);
    expect(state().isComplete, isFalse);
  });

  test('toggle adds and removes moods, allowing several', () {
    controller()
      ..toggle(Mood.calm)
      ..toggle(Mood.nostalgic);
    expect(state().moods, {Mood.calm, Mood.nostalgic});
    expect(state().isComplete, isTrue);

    controller().toggle(Mood.calm);
    expect(state().moods, {Mood.nostalgic});
  });

  test('intensity is clamped to 1..5 and can be cleared', () {
    controller().setIntensity(9);
    expect(state().intensity, 5);
    controller().setIntensity(0);
    expect(state().intensity, 1);
    controller().setIntensity(null);
    expect(state().intensity, isNull);
  });

  test('description is trimmed, emptied to null and length-limited', () {
    controller().setDescription('   ');
    expect(state().description, isNull);

    controller().setDescription('  rainy evening  ');
    expect(state().description, 'rainy evening');

    controller().setDescription('x' * 500);
    expect(state().description!.length, MoodInput.maxDescriptionLength);
  });

  test('every mood except Other has features in 0..100', () {
    for (final mood in Mood.values.where((m) => m != Mood.other)) {
      expect(mood.valence, inInclusiveRange(0, 100), reason: mood.name);
      expect(mood.energy, inInclusiveRange(0, 100), reason: mood.name);
    }
    expect(Mood.other.valence, isNull);
  });

  test('reset clears everything', () {
    controller()
      ..toggle(Mood.happy)
      ..setIntensity(4)
      ..setDescription('sunny');
    controller().reset();
    expect(state(), const MoodInput());
  });
}
