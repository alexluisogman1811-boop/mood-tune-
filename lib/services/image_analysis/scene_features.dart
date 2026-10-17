import '../../core/errors/app_failure.dart';

enum SceneSetting { indoor, outdoor, nature, city, cafe, unknown }

enum SceneLighting { dark, bright, warm, cool, soft, unknown }

enum SceneAtmosphere { cozy, dreamy, peaceful, dramatic, energetic, nostalgic }

enum EnvironmentalCue { rain, sunshine, fog, cloudy, snow, night }

/// Where a [SceneFeatures] value came from, so the UI never presents a
/// heuristic or a test fixture as if it were an AI model's answer.
enum AnalysisSource {
  remoteModel('AI scene analysis'),
  onDevice('Basic on-device analysis'),
  mock('Mock analysis (development only)');

  const AnalysisSource(this.label);
  final String label;
}

/// Structured description of the photographed environment. Describes the
/// scene only; it says nothing about the person's emotions.
class SceneFeatures {
  const SceneFeatures({
    required this.setting,
    required this.lighting,
    required this.atmosphere,
    required this.cues,
    required this.energy,
    required this.confidence,
    required this.source,
    this.palette = const [],
  }) : assert(energy >= 0 && energy <= 100),
       assert(confidence >= 0 && confidence <= 1);

  final SceneSetting setting;
  final SceneLighting lighting;
  final Set<SceneAtmosphere> atmosphere;
  final Set<EnvironmentalCue> cues;

  /// 0 (very quiet) to 100 (very lively).
  final int energy;

  /// 0..1, as reported by the analyser.
  final double confidence;
  final AnalysisSource source;

  /// Dominant colours as `#RRGGBB`.
  final List<String> palette;

  static const maxPaletteSize = 6;
  static final _hex = RegExp(r'^#[0-9a-fA-F]{6}$');

  /// Validates an untrusted payload (e.g. from the analysis backend).
  /// Unknown labels are dropped; malformed or out-of-range numbers throw
  /// [InvalidResponseFailure].
  factory SceneFeatures.fromJson(
    Object? json, {
    required AnalysisSource source,
  }) {
    if (json is! Map) throw const InvalidResponseFailure();

    final energy = json['energy'];
    final confidence = json['confidence'];
    if (energy is! num || !energy.isFinite || energy < 0 || energy > 100) {
      throw const InvalidResponseFailure('Scene energy is missing or invalid.');
    }
    if (confidence is! num ||
        !confidence.isFinite ||
        confidence < 0 ||
        confidence > 1) {
      throw const InvalidResponseFailure(
        'Scene confidence is missing or invalid.',
      );
    }

    return SceneFeatures(
      setting: _enumOr(
        SceneSetting.values,
        json['setting'],
        SceneSetting.unknown,
      ),
      lighting: _enumOr(
        SceneLighting.values,
        json['lighting'],
        SceneLighting.unknown,
      ),
      atmosphere: _enumSet(SceneAtmosphere.values, json['visualAtmosphere']),
      cues: _enumSet(EnvironmentalCue.values, json['environmentalCues']),
      energy: energy.round(),
      confidence: confidence.toDouble(),
      source: source,
      palette: _palette(json['palette']),
    );
  }

  Map<String, Object> toJson() => {
    'setting': setting.name,
    'lighting': lighting.name,
    'visualAtmosphere': [for (final a in atmosphere) a.name],
    'environmentalCues': [for (final c in cues) c.name],
    'energy': energy,
    'confidence': confidence,
    'palette': palette,
  };

  static T _enumOr<T extends Enum>(List<T> values, Object? raw, T fallback) {
    if (raw is! String) return fallback;
    final key = raw.trim().toLowerCase();
    for (final v in values) {
      if (v.name.toLowerCase() == key) return v;
    }
    return fallback;
  }

  static Set<T> _enumSet<T extends Enum>(List<T> values, Object? raw) {
    if (raw is! List) return {};
    final out = <T>{};
    for (final item in raw) {
      if (item is! String) continue;
      final key = item.trim().toLowerCase();
      for (final v in values) {
        if (v.name.toLowerCase() == key) out.add(v);
      }
    }
    return out;
  }

  static List<String> _palette(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<String>()
        .where(_hex.hasMatch)
        .map((c) => c.toUpperCase())
        .take(maxPaletteSize)
        .toList(growable: false);
  }
}
