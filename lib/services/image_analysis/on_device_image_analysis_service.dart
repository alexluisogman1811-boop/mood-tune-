import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../core/errors/app_failure.dart';
import 'image_analysis_service.dart';
import 'scene_features.dart';

/// Pixel-statistics analysis that runs entirely on the device. It measures
/// brightness, colour temperature, saturation, contrast and dominant colours.
/// It cannot recognise objects, so `setting` is always unknown and the
/// reported confidence is deliberately low.
class OnDeviceImageAnalysisService implements ImageAnalysisService {
  const OnDeviceImageAnalysisService();

  static const reportedConfidence = 0.35;

  @override
  bool get isRemote => false;

  @override
  Future<SceneFeatures> analyzeEnvironment(Uint8List jpegBytes) async {
    final stats = await Isolate.run(() => computeStats(jpegBytes));
    if (stats == null) {
      throw const InvalidResponseFailure('The photo could not be read.');
    }
    return featuresFromStats(stats);
  }

  /// Exposed for tests. Returns null when the bytes are not a decodable image.
  static PixelStats? computeStats(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final small = img.copyResize(decoded, width: math.min(64, decoded.width));

    var n = 0;
    double lumSum = 0, lumSq = 0, satSum = 0, warmSum = 0;
    final buckets = <int, List<int>>{};

    for (final p in small) {
      final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
      final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      final maxC = math.max(r, math.max(g, b));
      final minC = math.min(r, math.min(g, b));
      lumSum += lum;
      lumSq += lum * lum;
      satSum += maxC == 0 ? 0 : (maxC - minC) / maxC;
      warmSum += r - b;
      n++;

      final key = (r >> 5) << 6 | (g >> 5) << 3 | (b >> 5);
      final acc = buckets.putIfAbsent(key, () => [0, 0, 0, 0]);
      acc[0] += r;
      acc[1] += g;
      acc[2] += b;
      acc[3]++;
    }
    if (n == 0) return null;

    final meanLum = lumSum / n;
    final variance = math.max(0, lumSq / n - meanLum * meanLum);
    final top = buckets.values.toList()..sort((a, b) => b[3].compareTo(a[3]));
    String hex(int v) => v.toRadixString(16).padLeft(2, '0');

    return PixelStats(
      luminance: meanLum,
      contrast: math.sqrt(variance),
      saturation: satSum / n,
      warmth: warmSum / n,
      palette: [
        for (final c in top.take(5))
          '#${hex(c[0] ~/ c[3])}${hex(c[1] ~/ c[3])}${hex(c[2] ~/ c[3])}'
              .toUpperCase(),
      ],
    );
  }

  /// Exposed for tests: the thresholds that turn statistics into features.
  static SceneFeatures featuresFromStats(PixelStats s) {
    final lighting = switch (s) {
      _ when s.luminance < 60 => SceneLighting.dark,
      _ when s.luminance > 170 => SceneLighting.bright,
      _ when s.warmth > 20 => SceneLighting.warm,
      _ when s.warmth < -15 => SceneLighting.cool,
      _ => SceneLighting.soft,
    };

    final cues = <EnvironmentalCue>{
      if (s.luminance > 170 && s.warmth > 10) EnvironmentalCue.sunshine,
      if (s.saturation < 0.15 && s.luminance >= 90 && s.luminance <= 200)
        EnvironmentalCue.cloudy,
    };

    final energy =
        (s.saturation * 100 * 0.5 +
                (s.contrast / 128).clamp(0, 1) * 100 * 0.3 +
                s.luminance / 255 * 100 * 0.2)
            .round()
            .clamp(0, 100);

    final atmosphere = <SceneAtmosphere>{
      if (s.luminance < 110 && s.warmth > 10) SceneAtmosphere.cozy,
      if (s.luminance < 90 && s.contrast > 55) SceneAtmosphere.dramatic,
      if (s.saturation < 0.25 && s.contrast < 45) SceneAtmosphere.peaceful,
      if (s.saturation < 0.3 && s.luminance > 140 && s.contrast < 50)
        SceneAtmosphere.dreamy,
      if (energy >= 60) SceneAtmosphere.energetic,
    };

    return SceneFeatures(
      setting: SceneSetting.unknown,
      lighting: lighting,
      atmosphere: atmosphere,
      cues: cues,
      energy: energy,
      confidence: reportedConfidence,
      source: AnalysisSource.onDevice,
      palette: s.palette,
    );
  }
}

class PixelStats {
  const PixelStats({
    required this.luminance,
    required this.contrast,
    required this.saturation,
    required this.warmth,
    required this.palette,
  });

  /// 0..255
  final double luminance;

  /// Standard deviation of luminance, 0..~128.
  final double contrast;

  /// 0..1
  final double saturation;

  /// Mean (red - blue), -255..255. Positive is warm.
  final double warmth;
  final List<String> palette;
}
