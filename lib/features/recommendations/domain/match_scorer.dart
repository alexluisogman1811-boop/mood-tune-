import 'dart:math' as math;

import '../../../core/l10n/translate.dart';
import '../../../services/image_analysis/scene_features.dart';
import '../../mood/domain/mood.dart';
import '../../preferences/domain/music_preferences.dart';
import '../../reading/domain/reading.dart';
import 'track.dart';

/// The four parts of a match score.
enum MatchComponent {
  mood('Your mood'),
  atmosphere('Scene atmosphere'),
  preference('Your preferences'),
  energy('Requested energy');

  const MatchComponent(this.label);
  final String label;
}

/// Configurable component weights (default 40/25/20/15).
class MatchWeights {
  const MatchWeights({
    this.mood = 0.40,
    this.atmosphere = 0.25,
    this.preference = 0.20,
    this.energy = 0.15,
  }) : assert(mood >= 0 && atmosphere >= 0 && preference >= 0 && energy >= 0);

  final double mood;
  final double atmosphere;
  final double preference;
  final double energy;

  double of(MatchComponent c) => switch (c) {
    MatchComponent.mood => mood,
    MatchComponent.atmosphere => atmosphere,
    MatchComponent.preference => preference,
    MatchComponent.energy => energy,
  };
}

/// Everything the user told us, plus the (optional) scene.
class MatchContext {
  const MatchContext({
    required this.mood,
    required this.preferences,
    this.scene,
    this.reading,
  });

  final MoodInput mood;
  final MusicPreferences preferences;
  final SceneFeatures? scene;

  /// What the user is reading; null when they did not say.
  final ReadingKind? reading;
}

class TrackMatch {
  const TrackMatch({
    required this.track,
    required this.score,
    required this.components,
    required this.weights,
    required this.reasons,
  });

  final Track track;

  /// 0–100 estimate of compatibility.
  final int score;

  /// Only the components that could be computed, each 0–100.
  final Map<MatchComponent, double> components;

  /// Weights actually applied after redistribution; they sum to 1 (or the
  /// map is empty when nothing could be computed).
  final Map<MatchComponent, double> weights;

  /// Why the song fits, kept as data so it can be worded in any language.
  final List<MatchReason> reasons;

  /// The explanation in English.
  String get explanation => explanationIn('en');

  /// The explanation in [languageCode], e.g. `th`.
  String explanationIn(String languageCode) =>
      MatchScorer.describe(reasons, languageCode);
}

enum ReasonKind {
  mood,
  sceneFeel,
  sceneEnergy,
  genre,
  preferences,
  reading,
  energy,
}

/// One part of "why this song". [items] holds English labels or tag names.
class MatchReason {
  const MatchReason(this.kind, [this.items = const []]);
  final ReasonKind kind;
  final List<String> items;
}

/// Transparent, deterministic scoring:
///
/// `score = Σ wᵢ·sᵢ / Σ wᵢ` over the components that are available, so
/// missing information redistributes weight rather than counting as zero.
/// This estimates preference compatibility; it is not a measurement of
/// emotion.
class MatchScorer {
  const MatchScorer({this.weights = const MatchWeights()});

  final MatchWeights weights;

  /// Score used when no component can be computed at all.
  static const neutralScore = 50;

  TrackMatch score(Track track, MatchContext ctx) {
    final components = <MatchComponent, double>{
      MatchComponent.mood: ?moodMatch(track, ctx.mood),
      if (ctx.scene case final scene?)
        MatchComponent.atmosphere: ?atmosphereMatch(track, scene),
      MatchComponent.preference: ?preferenceMatch(
        track,
        ctx.preferences,
        ctx.reading,
      ),
      MatchComponent.energy: ?energyMatch(track, ctx.preferences, ctx.reading),
    };
    final applied = normalizedWeights(components.keys, weights);
    final total = applied.isEmpty
        ? neutralScore.toDouble()
        : applied.entries.fold<double>(
            0,
            (sum, e) => sum + e.value * components[e.key]!,
          );
    return TrackMatch(
      track: track,
      score: total.round().clamp(0, 100),
      components: components,
      weights: applied,
      reasons: explain(track, ctx, components),
    );
  }

  /// Rescales the weights of [available] components to sum to 1. If all of
  /// them are weighted zero, they share equally.
  static Map<MatchComponent, double> normalizedWeights(
    Iterable<MatchComponent> available,
    MatchWeights weights,
  ) {
    final list = available.toList();
    if (list.isEmpty) return const {};
    final sum = list.fold<double>(0, (s, c) => s + weights.of(c));
    return {
      for (final c in list) c: sum == 0 ? 1 / list.length : weights.of(c) / sum,
    };
  }

  // ---- Components -------------------------------------------------------

  /// Points on the valence/energy plane for each selected mood. Intensity
  /// pushes a point away from neutral (50, 50); 3 or unset leaves it roughly
  /// as defined.
  static Map<Mood, (double, double)> moodTargets(MoodInput mood) {
    final factor = mood.intensity == null
        ? 1.0
        : 0.625 + (mood.intensity! - 1) * 0.125; // 1→0.625 … 5→1.125
    return {
      for (final m in Mood.values)
        if (mood.moods.contains(m) && m.valence != null && m.energy != null)
          m: (
            (50 + (m.valence! - 50) * factor).clamp(0, 100).toDouble(),
            (50 + (m.energy! - 50) * factor).clamp(0, 100).toDouble(),
          ),
    };
  }

  /// Similarity (0–100) between a track and one mood point, using whichever
  /// of valence and energy the track has. Null when it has neither.
  static double? similarity(Track t, (double, double) target) {
    final (tv, te) = target;
    final v = t.valence, e = t.energy;
    if (v != null && e != null) {
      final d = math.sqrt(math.pow(v - tv, 2) + math.pow(e - te, 2));
      return 100 * (1 - d / (100 * math.sqrt2));
    }
    if (v != null) return 100 - (v - tv).abs();
    if (e != null) return 100 - (e - te).abs();
    return null;
  }

  /// Blends the best-fitting mood (70%) with the average fit (30%), so a
  /// song that suits one of several conflicting moods still scores well,
  /// while songs that suit all of them score best.
  static double? moodMatch(Track t, MoodInput mood) {
    final sims = [
      for (final target in moodTargets(mood).values) ?similarity(t, target),
    ];
    if (sims.isEmpty) return null;
    final best = sims.reduce(math.max);
    final mean = sims.reduce((a, b) => a + b) / sims.length;
    return (best * 0.7 + mean * 0.3).clamp(0, 100);
  }

  /// Energy closeness and shared atmosphere/weather tags, pulled toward
  /// neutral (50) in proportion to how unsure the scene analysis was.
  static double? atmosphereMatch(Track t, SceneFeatures scene) {
    final parts = <double>[];
    if (t.energy case final e?) {
      parts.add(100 - (scene.energy - e).abs().toDouble());
    }

    final sceneTagCount = scene.atmosphere.length + scene.cues.length;
    if (sceneTagCount > 0 && (t.atmosphere != null || t.cues != null)) {
      final shared =
          scene.atmosphere.intersection(t.atmosphere ?? const {}).length +
          scene.cues.intersection(t.cues ?? const {}).length;
      parts.add(100 * shared / sceneTagCount);
    }
    if (parts.isEmpty) return null;
    final raw = parts.reduce((a, b) => a + b) / parts.length;
    return (50 + (raw - 50) * scene.confidence).clamp(0, 100);
  }

  /// Average of the taste checks that apply. Null when the user set no
  /// taste preferences or the track lacks the metadata to check them.
  /// Reading that prefers no lyrics counts as a taste check unless the user
  /// chose a vocal preference or song languages themselves.
  static double? preferenceMatch(
    Track t,
    MusicPreferences p, [
    ReadingKind? reading,
  ]) {
    final readingCheck =
        reading != null &&
        reading.preferInstrumental &&
        p.vocal == VocalPreference.any &&
        p.languages.isEmpty &&
        t.isInstrumental != null;
    if (!p.hasTastePreferences && !readingCheck) return null;
    final parts = <double>[
      // Lyrics are not ruled out, just less suited to reading.
      if (readingCheck) t.isInstrumental! ? 100 : 30,
      if (p.genres.isNotEmpty && t.genres.isNotEmpty)
        p.genres.intersection(t.genres).isNotEmpty ? 100 : 0,
      if (p.languages.isNotEmpty &&
          t.isInstrumental != true &&
          t.language != null)
        p.languages.contains(t.language) ? 100 : 0,
      if (p.vocal != VocalPreference.any && t.isInstrumental != null)
        (p.vocal == VocalPreference.instrumental) == t.isInstrumental ? 100 : 0,
      if (p.discovery != DiscoveryPreference.balanced && t.popularity != null)
        p.discovery == DiscoveryPreference.familiar
            ? t.popularity!.toDouble()
            : 100 - t.popularity!.toDouble(),
    ];
    if (parts.isEmpty) return null;
    return parts.reduce((a, b) => a + b) / parts.length;
  }

  /// Closeness to the energy the user asked for or, failing that, the
  /// energy that suits what they are reading.
  static double? energyMatch(
    Track t,
    MusicPreferences p, [
    ReadingKind? reading,
  ]) {
    final target = p.energy?.target ?? reading?.targetEnergy;
    final e = t.energy;
    if (target == null || e == null) return null;
    return 100 - (target - e).abs().toDouble();
  }

  // ---- Explanation ------------------------------------------------------

  static const _strong = 60.0;

  static List<MatchReason> explain(
    Track t,
    MatchContext ctx,
    Map<MatchComponent, double> c,
  ) {
    bool strong(MatchComponent m) => (c[m] ?? 0) >= _strong;
    final reasons = <MatchReason>[];

    if (strong(MatchComponent.mood)) {
      // Name only the moods this track actually fits, best first.
      final fits = [
        for (final MapEntry(key: m, value: target) in moodTargets(
          ctx.mood,
        ).entries)
          if (similarity(t, target) case final s? when s >= _strong) (m, s),
      ]..sort((a, b) => b.$2.compareTo(a.$2));
      reasons.add(
        MatchReason(ReasonKind.mood, [
          for (final (m, _) in fits.take(2)) m.label,
        ]),
      );
    }

    final scene = ctx.scene;
    if (scene != null && strong(MatchComponent.atmosphere)) {
      final shared = [
        for (final a in scene.atmosphere)
          if (t.atmosphere?.contains(a) ?? false) a.name,
        for (final cue in scene.cues)
          if (t.cues?.contains(cue) ?? false) cue.name,
      ];
      reasons.add(
        shared.isNotEmpty
            ? MatchReason(ReasonKind.sceneFeel, shared.take(2).toList())
            : const MatchReason(ReasonKind.sceneEnergy),
      );
    }

    final reading = ctx.reading;
    final prefs = ctx.preferences;
    var readingFits = false;
    if (strong(MatchComponent.preference)) {
      final liked = [
        for (final g in Genre.values)
          if (prefs.genres.contains(g) && t.genres.contains(g)) g.label,
      ];
      if (liked.isNotEmpty) {
        reasons.add(MatchReason(ReasonKind.genre, [liked.first]));
      } else if (prefs.hasTastePreferences) {
        reasons.add(const MatchReason(ReasonKind.preferences));
      } else {
        readingFits = reading != null; // only the reading check applied
      }
    }

    final energyPref = prefs.energy;
    if (strong(MatchComponent.energy)) {
      if (energyPref != null) {
        reasons.add(MatchReason(ReasonKind.energy, [energyPref.label]));
      } else {
        readingFits = reading != null;
      }
    }
    if (readingFits) {
      reasons.add(MatchReason(ReasonKind.reading, [reading!.reason]));
    }
    return reasons;
  }

  /// Words [reasons] as one sentence in [languageCode].
  static String describe(List<MatchReason> reasons, String languageCode) {
    final thai = languageCode == 'th';
    String tr(String english) => translate(english, languageCode);
    String tag(String name) =>
        tr(name.isEmpty ? name : name[0].toUpperCase() + name.substring(1));

    if (reasons.isEmpty) {
      return tr('A looser match — it differs from some of what you told us.');
    }
    if (thai) {
      final parts = [
        for (final r in reasons)
          switch (r.kind) {
            ReasonKind.mood =>
              'เข้ากับอารมณ์${_joinThai(r.items.map(tr))}ของคุณ',
            ReasonKind.sceneFeel =>
              'เหมาะกับบรรยากาศ${_joinThai(r.items.map(tag))}ในฉากของคุณ',
            ReasonKind.sceneEnergy => 'เข้ากับพลังของสิ่งรอบตัวคุณ',
            ReasonKind.genre => 'เป็นแนว${tr(r.items.first)}ตามที่คุณต้องการ',
            ReasonKind.preferences => 'ตรงกับความชอบในการฟังของคุณ',
            ReasonKind.reading => tr(r.items.first),
            ReasonKind.energy => 'มีพลังแบบ${tr(r.items.first)}ที่คุณต้องการ',
          },
      ];
      return _joinThai(parts, separator: ' ', last: ' และ');
    }
    final parts = [
      for (final r in reasons)
        switch (r.kind) {
          ReasonKind.mood =>
            'fits your ${_joinAll([for (final m in r.items) m.toLowerCase()])} mood',
          ReasonKind.sceneFeel =>
            'suits the ${_joinAll(r.items)} feel of your scene',
          ReasonKind.sceneEnergy => 'matches the energy of your surroundings',
          ReasonKind.genre => 'is ${r.items.first} like you asked for',
          ReasonKind.preferences => 'lines up with your listening preferences',
          ReasonKind.reading => r.items.first,
          ReasonKind.energy =>
            'has the ${r.items.first.toLowerCase()} energy you wanted',
        },
    ];
    final sentence = _joinAll(parts);
    return '${sentence[0].toUpperCase()}${sentence.substring(1)}.';
  }

  static String _joinAll(List<String> items) => switch (items.length) {
    0 => '',
    1 => items.first,
    _ => '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}',
  };

  /// Thai lists: "ก ข และค".
  static String _joinThai(
    Iterable<String> items, {
    String separator = ' ',
    String last = 'และ',
  }) {
    final list = items.toList();
    if (list.length < 2) return list.join();
    return '${list.sublist(0, list.length - 1).join(separator)}$last'
        '${list.last}';
  }
}
