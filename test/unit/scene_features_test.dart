import 'package:flutter_test/flutter_test.dart';
import 'package:moodscape/core/errors/app_failure.dart';
import 'package:moodscape/services/image_analysis/scene_features.dart';

SceneFeatures _parse(Object? json) =>
    SceneFeatures.fromJson(json, source: AnalysisSource.remoteModel);

void main() {
  test('parses the documented example payload', () {
    final f = _parse({
      'setting': 'outdoor',
      'lighting': 'soft',
      'visualAtmosphere': ['peaceful', 'dreamy'],
      'environmentalCues': ['cloudy'],
      'energy': 35,
      'confidence': 0.85,
    });
    expect(f.setting, SceneSetting.outdoor);
    expect(f.lighting, SceneLighting.soft);
    expect(f.atmosphere, {SceneAtmosphere.peaceful, SceneAtmosphere.dreamy});
    expect(f.cues, {EnvironmentalCue.cloudy});
    expect(f.energy, 35);
    expect(f.confidence, 0.85);
    expect(f.source, AnalysisSource.remoteModel);
  });

  test('unknown labels are dropped, not trusted', () {
    final f = _parse({
      'setting': 'spaceship',
      'lighting': 42,
      'visualAtmosphere': ['peaceful', 'sad person', 7],
      'environmentalCues': 'rain',
      'energy': 50,
      'confidence': 0.5,
    });
    expect(f.setting, SceneSetting.unknown);
    expect(f.lighting, SceneLighting.unknown);
    expect(f.atmosphere, {SceneAtmosphere.peaceful});
    expect(f.cues, isEmpty);
  });

  test('labels are matched case-insensitively', () {
    final f = _parse({'setting': ' Cafe ', 'energy': 10, 'confidence': 1});
    expect(f.setting, SceneSetting.cafe);
  });

  test('palette keeps only valid hex colours, capped', () {
    final f = _parse({
      'energy': 0,
      'confidence': 0,
      'palette': ['#aabbcc', 'red', '#12345', ...List.filled(10, '#000000')],
    });
    expect(f.palette.first, '#AABBCC');
    expect(f.palette.length, SceneFeatures.maxPaletteSize);
  });

  group('rejects invalid payloads', () {
    for (final (name, payload) in [
      ('non-map', ['energy', 1]),
      ('null', null),
      ('missing energy', {'confidence': 0.5}),
      ('energy above 100', {'energy': 101, 'confidence': 0.5}),
      ('negative energy', {'energy': -1, 'confidence': 0.5}),
      ('energy as string', {'energy': '50', 'confidence': 0.5}),
      ('NaN energy', {'energy': double.nan, 'confidence': 0.5}),
      ('missing confidence', {'energy': 50}),
      ('confidence above 1', {'energy': 50, 'confidence': 1.2}),
    ]) {
      test(name, () {
        expect(() => _parse(payload), throwsA(isA<InvalidResponseFailure>()));
      });
    }
  });

  test('boundary values 0/100 and 0/1 are accepted', () {
    expect(_parse({'energy': 0, 'confidence': 0}).energy, 0);
    expect(_parse({'energy': 100, 'confidence': 1}).energy, 100);
  });

  test('toJson round-trips', () {
    final original = _parse({
      'setting': 'city',
      'lighting': 'dark',
      'visualAtmosphere': ['dramatic'],
      'environmentalCues': ['rain', 'night'],
      'energy': 62,
      'confidence': 0.7,
      'palette': ['#101820'],
    });
    final copy = _parse(original.toJson());
    expect(copy.toJson(), original.toJson());
  });
}
