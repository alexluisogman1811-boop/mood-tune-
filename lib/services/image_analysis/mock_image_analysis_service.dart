import 'dart:typed_data';

import 'scene_features.dart';
import 'image_analysis_service.dart';

/// Deterministic analyser for tests and UI development. Its results are
/// tagged [AnalysisSource.mock] so they are never shown as real analysis.
class MockImageAnalysisService implements ImageAnalysisService {
  MockImageAnalysisService({this.result, this.error, this.isRemote = false});

  final SceneFeatures? result;
  final Object? error;
  int calls = 0;

  @override
  final bool isRemote;

  static const sample = SceneFeatures(
    setting: SceneSetting.outdoor,
    lighting: SceneLighting.soft,
    atmosphere: {SceneAtmosphere.peaceful, SceneAtmosphere.dreamy},
    cues: {EnvironmentalCue.cloudy},
    energy: 35,
    confidence: 0.85,
    source: AnalysisSource.mock,
    palette: ['#8FA3B8', '#3E4A5C'],
  );

  @override
  Future<SceneFeatures> analyzeEnvironment(Uint8List jpegBytes) async {
    calls++;
    final e = error;
    if (e != null) throw e;
    return result ?? sample;
  }
}
