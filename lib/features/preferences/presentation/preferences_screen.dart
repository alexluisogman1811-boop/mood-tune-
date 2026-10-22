import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../account/application/account_providers.dart';
import '../../account/domain/account.dart';
import '../../../core/l10n/l10n.dart';
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
    final entitlements = ref.watch(entitlementsProvider);
    final premium = entitlements.premium;

    Widget heading(String text, [String? hint]) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr(text), style: theme.textTheme.titleMedium),
          if (hint != null)
            Text(
              context.tr(hint),
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
        title: Text(context.tr('Music preferences')),
        actions: [
          TextButton(
            onPressed: () => context.push(AppRoutes.platform),
            child: Text(context.tr('Skip')),
          ),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Text(
                context.tr('All optional. Skip to use balanced defaults.'),
                style: theme.textTheme.bodyMedium,
              ),
              heading('Favourite genres'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in Genre.values)
                    FilterChip(
                      label: Text(context.tr(g.label)),
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
                      label: Text(context.tr(l.label)),
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
                label: (v) => context.tr(v.label),
                selected: d.vocal,
                onChanged: (v) => _update(d.copyWith(vocal: v)),
              ),
              heading('Familiar or new?'),
              _Segmented<DiscoveryPreference>(
                values: DiscoveryPreference.values,
                label: (v) => context.tr(v.label),
                selected: d.discovery,
                onChanged: (v) => _update(d.copyWith(discovery: v)),
              ),
              heading('Energy', 'Tap again to clear.'),
              _Segmented<EnergyPreference>(
                values: EnergyPreference.values,
                label: (v) => context.tr(v.label),
                selected: d.energy,
                allowEmpty: true,
                onChanged: (v) => _update(d.copyWith(energy: () => v)),
              ),
              heading(
                'Playlist length',
                premium ? null : '20 and 30 songs are Premium.',
              ),
              _Segmented<int>(
                values: MusicPreferences.playlistLengths,
                label: (v) => context.tr('{count} songs', {'count': v}),
                // Free playlists are capped, so show the length they get.
                selected: premium
                    ? d.playlistLength
                    : entitlements.maxPlaylistLength(d.playlistLength),
                enabled: (v) => premium || v <= FreeLimits.playlistLength,
                onChanged: (v) => _update(d.copyWith(playlistLength: v)),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Allow explicit content')),
                value: d.allowExplicit,
                onChanged: (v) => _update(d.copyWith(allowExplicit: v)),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saveAndContinue,
                child: Text(context.tr('Save and continue')),
              ),
              TextButton(
                onPressed: () => _update(const MusicPreferences()),
                child: Text(context.tr('Reset to defaults')),
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
    this.enabled,
  });

  final List<T> values;
  final String Function(T) label;
  final T? selected;
  final ValueChanged<T?> onChanged;
  final bool allowEmpty;

  /// Null means every choice is available.
  final bool Function(T)? enabled;

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
            ButtonSegment<T>(
              value: v,
              label: Text(label(v)),
              enabled: enabled?.call(v) ?? true,
            ),
        ],
        selected: {?current},
        onSelectionChanged: (s) => onChanged(s.isEmpty ? null : s.first),
      ),
    );
  }
}
