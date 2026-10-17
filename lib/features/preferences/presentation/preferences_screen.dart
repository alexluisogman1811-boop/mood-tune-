import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../application/preferences_controller.dart';
import '../domain/music_preferences.dart';

class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  late MusicPreferences _draft = ref.read(musicPreferencesProvider);

  void _update(MusicPreferences next) => setState(() => _draft = next);

  Set<T> _toggled<T>(Set<T> set, T value) =>
      set.contains(value) ? ({...set}..remove(value)) : {...set, value};

  Future<void> _saveAndContinue() async {
    await ref.read(musicPreferencesProvider.notifier).save(_draft);
    if (mounted) context.push(AppRoutes.platform);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = _draft;

    Widget heading(String text, [String? hint]) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: theme.textTheme.titleMedium),
          if (hint != null)
            Text(
              hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Music preferences'),
        actions: [
          TextButton(
            onPressed: () => context.push(AppRoutes.platform),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Text(
                'All optional. Skip to use balanced defaults.',
                style: theme.textTheme.bodyMedium,
              ),
              heading('Favourite genres'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in Genre.values)
                    FilterChip(
                      label: Text(g.label),
                      selected: d.genres.contains(g),
                      onSelected: (_) =>
                          _update(d.copyWith(genres: _toggled(d.genres, g))),
                    ),
                ],
              ),
              heading('Preferred language', 'None selected means any.'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final l in MusicLanguage.values)
                    FilterChip(
                      label: Text(l.label),
                      selected: d.languages.contains(l),
                      onSelected: (_) => _update(
                        d.copyWith(languages: _toggled(d.languages, l)),
                      ),
                    ),
                ],
              ),
              heading('Vocals'),
              _Segmented<VocalPreference>(
                values: VocalPreference.values,
                label: (v) => v.label,
                selected: d.vocal,
                onChanged: (v) => _update(d.copyWith(vocal: v)),
              ),
              heading('Familiar or new?'),
              _Segmented<DiscoveryPreference>(
                values: DiscoveryPreference.values,
                label: (v) => v.label,
                selected: d.discovery,
                onChanged: (v) => _update(d.copyWith(discovery: v)),
              ),
              heading('Energy', 'Tap again to clear.'),
              _Segmented<EnergyPreference>(
                values: EnergyPreference.values,
                label: (v) => v.label,
                selected: d.energy,
                allowEmpty: true,
                onChanged: (v) => _update(d.copyWith(energy: () => v)),
              ),
              heading('Playlist length'),
              _Segmented<int>(
                values: MusicPreferences.playlistLengths,
                label: (v) => '$v songs',
                selected: d.playlistLength,
                onChanged: (v) => _update(d.copyWith(playlistLength: v)),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow explicit content'),
                value: d.allowExplicit,
                onChanged: (v) => _update(d.copyWith(allowExplicit: v)),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saveAndContinue,
                child: const Text('Save and continue'),
              ),
              TextButton(
                onPressed: () => _update(const MusicPreferences()),
                child: const Text('Reset to defaults'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.values,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.allowEmpty = false,
  });

  final List<T> values;
  final String Function(T) label;
  final T? selected;
  final ValueChanged<T?> onChanged;
  final bool allowEmpty;

  @override
  Widget build(BuildContext context) {
    final current = selected;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<T>(
        showSelectedIcon: false,
        emptySelectionAllowed: allowEmpty,
        segments: [
          for (final v in values)
            ButtonSegment<T>(value: v, label: Text(label(v))),
        ],
        selected: {?current},
        onSelectionChanged: (s) => onChanged(s.isEmpty ? null : s.first),
      ),
    );
  }
}
