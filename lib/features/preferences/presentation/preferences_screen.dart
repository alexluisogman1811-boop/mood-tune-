import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../application/artist_catalog.dart';
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
              heading('Bands you like', 'Search and tap to add. Optional.'),
              _ArtistPicker(
                picked: d.artists,
                only: d.artistsOnly,
                languages: d.languages,
                onChanged: (artists, only) =>
                    _update(d.copyWith(artists: artists, artistsOnly: only)),
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
              heading('Playlist length'),
              _Segmented<int>(
                values: MusicPreferences.playlistLengths,
                label: (v) => context.tr('{count} songs', {'count': v}),
                selected: d.playlistLength,
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

/// Picks bands from the catalogue. Only names the catalogue actually has
/// can be added, so a pick always matches at least one song.
class _ArtistPicker extends ConsumerStatefulWidget {
  const _ArtistPicker({
    required this.picked,
    required this.only,
    required this.languages,
    required this.onChanged,
  });

  final Set<String> picked;
  final bool only;
  final Set<MusicLanguage> languages;
  final void Function(Set<String> artists, bool only) onChanged;

  @override
  ConsumerState<_ArtistPicker> createState() => _ArtistPickerState();
}

class _ArtistPickerState extends ConsumerState<_ArtistPicker> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _add(String name) {
    if (widget.picked.length >= MusicPreferences.maxArtists) return;
    widget.onChanged({...widget.picked, name}, widget.only);
    _search.clear();
    setState(() => _query = '');
  }

  void _remove(String name) {
    final key = MusicPreferences.artistKey(name);
    final next = {
      for (final a in widget.picked)
        if (MusicPreferences.artistKey(a) != key) a,
    };
    // "Only these bands" means nothing once none are picked.
    widget.onChanged(next, next.isEmpty ? false : widget.only);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = ref.watch(artistCatalogProvider).value ?? const [];
    final full = widget.picked.length >= MusicPreferences.maxArtists;
    final suggestions = suggestArtists(
      all,
      query: _query,
      picked: widget.picked,
      languages: widget.languages,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _search,
          enabled: !full,
          decoration: InputDecoration(
            labelText: context.tr('Search for a band'),
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        if (widget.picked.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in widget.picked)
                InputChip(
                  label: Text(name),
                  onDeleted: () => _remove(name),
                  deleteButtonTooltipMessage: context.tr('Remove'),
                ),
            ],
          ),
        ],
        if (full)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              context.tr('You can pick up to {count} bands.', {
                'count': MusicPreferences.maxArtists,
              }),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else if (suggestions.isEmpty && _query.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              context.tr('No band with that name is in the catalogue.'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in suggestions)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  // A name and a song count need no translating.
                  label: Text('${a.name} · ${a.songs}'),
                  onPressed: () => _add(a.name),
                ),
            ],
          ),
        ],
        if (widget.picked.isNotEmpty)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('Only these bands')),
            subtitle: Text(
              context.tr(
                'On: only their songs, so the playlist may be shorter.',
              ),
            ),
            value: widget.only,
            onChanged: (v) => widget.onChanged(widget.picked, v),
          ),
      ],
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
