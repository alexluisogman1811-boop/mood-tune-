import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodscape/core/errors/app_failure.dart';
import 'package:moodscape/features/atmosphere/domain/atmosphere_analyzer.dart';
import 'package:moodscape/services/image_analysis/mock_image_analysis_service.dart';
import 'package:moodscape/services/image_analysis/scene_features.dart';

final _photo = Uint8List.fromList([1, 2, 3]);

const _localResult = SceneFeatures(
  setting: SceneSetting.unknown,
  lighting: SceneLighting.warm,
  atmosphere: {},
  cues: {},
  energy: 40,
  confidence: 0.35,
  source: AnalysisSource.onDevice,
);

void main() {
  late MockImageAnalysisService local;

  setUp(() => local = MockImageAnalysisService(result: _localResult));

  test('no photo skips analysis entirely', () async {
    final remote = MockImageAnalysisService(isRemote: true);
    final analyzer = AtmosphereAnalyzer(local: local, remote: remote);

    final outcome = await analyzer.analyze(null, allowRemote: true);

    expect(outcome.features, isNull);
    expect(outcome.notice, isNotNull);
    expect(local.calls + remote.calls, 0);
  });

  test('uses remote when allowed and it succeeds', () async {
    final remote = MockImageAnalysisService(isRemote: true);
    final analyzer = AtmosphereAnalyzer(local: local, remote: remote);

    final outcome = await analyzer.analyze(_photo, allowRemote: true);

    expect(outcome.features, same(MockImageAnalysisService.sample));
    expect(outcome.usedFallback, isFalse);
    expect(local.calls, 0);
  });

  test('never calls remote without consent', () async {
    final remote = MockImageAnalysisService(isRemote: true);
    final analyzer = AtmosphereAnalyzer(local: local, remote: remote);

    final outcome = await analyzer.analyze(_photo, allowRemote: false);

    expect(remote.calls, 0);
    expect(outcome.features, same(_localResult));
    expect(outcome.usedFallback, isFalse);
  });

  test('falls back to on-device when remote fails', () async {
    final remote = MockImageAnalysisService(
      isRemote: true,
      error: const NetworkFailure(),
    );
    final analyzer = AtmosphereAnalyzer(local: local, remote: remote);

    final outcome = await analyzer.analyze(_photo, allowRemote: true);

    expect(outcome.features, same(_localResult));
    expect(outcome.usedFallback, isTrue);
    expect(outcome.notice, contains('on-device'));
  });

  test('continues with mood only when nothing can analyse the photo', () async {
    final broken = MockImageAnalysisService(
      error: const InvalidResponseFailure('The photo could not be read.'),
    );
    final analyzer = AtmosphereAnalyzer(local: broken);

    final outcome = await analyzer.analyze(_photo, allowRemote: true);

    expect(outcome.features, isNull);
    expect(outcome.usedFallback, isTrue);
    expect(outcome.notice, contains('mood only'));
  });
}
