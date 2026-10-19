import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodscape/core/l10n/thai.dart';
import 'package:moodscape/core/l10n/translate.dart';
import 'package:moodscape/features/mood/domain/mood.dart';
import 'package:moodscape/features/music_platform/application/platform_providers.dart';
import 'package:moodscape/features/preferences/domain/music_preferences.dart';
import 'package:moodscape/features/reading/domain/reading.dart';
import 'package:moodscape/features/recommendations/domain/match_scorer.dart';
import 'package:moodscape/features/recommendations/domain/recommendation_engine.dart';
import 'package:moodscape/services/image_analysis/scene_features.dart';

/// Every English literal passed as the first argument of `tr(...)` or
/// `translate(...)` anywhere in lib/, with adjacent literals joined.
Set<String> _literalKeys() {
  const lit = r"'((?:[^'\\]|\\.)*)'";
  final keys = <String>{};
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final s = f.readAsStringSync();
    for (final m in RegExp(r'\b(?:tr|translate)\(').allMatches(s)) {
      var depth = 0, i = m.end;
      for (; i < s.length; i++) {
        final c = s[i];
        if (c == "'") {
          for (i++; s[i] != "'"; i++) {
            if (s[i] == r'\') i++;
          }
          continue;
        }
        if ('([{'.contains(c)) depth++;
        if (')]}'.contains(c)) {
          if (depth == 0) break;
          depth--;
        }
        if (c == ',' && depth == 0) break;
      }
      final arg = s.substring(m.end, i);
      for (final run in RegExp('(?:$lit\\s*)+').allMatches(arg)) {
        final text = RegExp(lit).allMatches(run[0]!).map((p) => p[1]!).join();
        if (text.isEmpty || text.contains(r'$')) continue;
        keys.add(text.replaceAll(r"\'", "'").replaceAll(r'\n', '\n'));
      }
    }
  }
  return keys;
}

Set<String> _placeholders(String s) => {
  for (final m in RegExp(r'\{(\w+)\}').allMatches(s)) m[1]!,
};

String _capitalized(Enum e) => e.name[0].toUpperCase() + e.name.substring(1);

void main() {
  test('every text the UI translates has a Thai version', () {
    final keys = _literalKeys();
    expect(keys.length, greaterThan(100), reason: 'the scan found the UI');
    final missing = keys.where((k) => !thaiStrings.containsKey(k)).toList();
    expect(missing, isEmpty);
  });

  test('labels shown through variables have Thai versions', () {
    final labels = [
      for (final m in Mood.values) m.label,
      for (final g in Genre.values) g.label,
      for (final l in MusicLanguage.values) l.label,
      for (final v in VocalPreference.values) v.label,
      for (final d in DiscoveryPreference.values) d.label,
      for (final e in EnergyPreference.values) e.label,
      for (final q in QuickFilter.values) q.label,
      for (final c in MatchComponent.values) c.label,
      for (final s in AnalysisSource.values) s.label,
      for (final p in MusicPlatform.values) p.label,
      for (final r in ReadingKind.values) ...[r.label, r.description, r.reason],
      for (final s in SceneSetting.values)
        if (s != SceneSetting.unknown) _capitalized(s),
      for (final l in SceneLighting.values)
        if (l != SceneLighting.unknown) _capitalized(l),
      for (final a in SceneAtmosphere.values) _capitalized(a),
      for (final c in EnvironmentalCue.values) _capitalized(c),
    ];
    final missing = labels.where((l) => !thaiStrings.containsKey(l)).toList();
    expect(missing, isEmpty);
  });

  test('Thai texts keep the same placeholders as the English', () {
    for (final MapEntry(key: en, value: th) in thaiStrings.entries) {
      expect(_placeholders(th), _placeholders(en), reason: en);
    }
  });

  group('translate', () {
    test('fills placeholders in either language', () {
      expect(translate('{count} songs', 'en', {'count': 20}), '20 songs');
      expect(translate('{count} songs', 'th', {'count': 20}), '20 เพลง');
    });

    test('falls back to English for unknown text or languages', () {
      expect(translate('Brand new text', 'th'), 'Brand new text');
      expect(translate('Settings', 'fr'), 'Settings');
    });
  });
}
