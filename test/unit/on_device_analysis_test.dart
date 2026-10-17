import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:moodscape/services/image_analysis/on_device_image_analysis_service.dart';
import 'package:moodscape/services/image_analysis/scene_features.dart';

Uint8List _solid(int r, int g, int b, {int w = 40, int h = 30}) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return img.encodePng(image);
}

PixelStats _stats({
  double luminance = 120,
  double contrast = 30,
  double saturation = 0.3,
  double warmth = 0,
}) => PixelStats(
  luminance: luminance,
  contrast: contrast,
  saturation: saturation,
  warmth: warmth,
  palette: const [],
);

void main() {
  group('computeStats', () {
    test('solid colour yields exact palette and zero contrast', () {
      final s = OnDeviceImageAnalysisService.computeStats(_solid(255, 0, 0))!;
      expect(s.palette, ['#FF0000']);
      expect(s.contrast, closeTo(0, 0.001));
      expect(s.saturation, closeTo(1, 0.001));
      expect(s.warmth, closeTo(255, 0.001));
    });

    test('returns null for bytes that are not an image', () {
      expect(
        OnDeviceImageAnalysisService.computeStats(Uint8List.fromList([1, 2])),
        isNull,
      );
    });
  });

  group('featuresFromStats', () {
    test('dark and warm reads as dark lighting with a cozy feel', () {
      final f = OnDeviceImageAnalysisService.featuresFromStats(
        _stats(luminance: 45, warmth: 40),
      );
      expect(f.lighting, SceneLighting.dark);
      expect(f.atmosphere, contains(SceneAtmosphere.cozy));
    });

    test('bright and warm reads as sunshine', () {
      final f = OnDeviceImageAnalysisService.featuresFromStats(
        _stats(luminance: 200, warmth: 30),
      );
      expect(f.lighting, SceneLighting.bright);
      expect(f.cues, contains(EnvironmentalCue.sunshine));
    });

    test('grey, low-contrast scene reads as cloudy and peaceful', () {
      final f = OnDeviceImageAnalysisService.featuresFromStats(
        _stats(luminance: 140, saturation: 0.05, contrast: 20),
      );
      expect(f.cues, contains(EnvironmentalCue.cloudy));
      expect(f.atmosphere, contains(SceneAtmosphere.peaceful));
    });

    test('saturated, contrasty scene is energetic', () {
      final f = OnDeviceImageAnalysisService.featuresFromStats(
        _stats(luminance: 150, saturation: 0.9, contrast: 100),
      );
      expect(f.energy, greaterThanOrEqualTo(60));
      expect(f.atmosphere, contains(SceneAtmosphere.energetic));
    });

    test('is honest about its limits', () {
      final f = OnDeviceImageAnalysisService.featuresFromStats(_stats());
      expect(f.setting, SceneSetting.unknown);
      expect(f.source, AnalysisSource.onDevice);
      expect(f.confidence, OnDeviceImageAnalysisService.reportedConfidence);
    });

    test('energy stays within 0..100 at extremes', () {
      final hi = OnDeviceImageAnalysisService.featuresFromStats(
        _stats(luminance: 255, saturation: 1, contrast: 500),
      );
      final lo = OnDeviceImageAnalysisService.featuresFromStats(
        _stats(luminance: 0, saturation: 0, contrast: 0),
      );
      expect(hi.energy, inInclusiveRange(0, 100));
      expect(lo.energy, 0);
    });
  });
}
