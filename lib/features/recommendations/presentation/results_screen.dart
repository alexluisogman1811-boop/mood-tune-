import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../feedback/presentation/feedback_invite.dart';
import '../../mood/application/mood_controller.dart';
import '../../mood/domain/mood.dart';
import '../../preferences/domain/music_preferences.dart';
import '../application/playlist_controller.dart';
import '../application/recommendations_controller.dart';
import '../domain/match_scorer.dart';
import '../domain/recommendation_engine.dart';
import '../domain/track.dart';
import 'dislike_action.dart';
import 'export_sheet.dart';
import 'new_analysis.dart';
import 'track_card.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recs = ref.watch(recommendationsProvider);
    final matches = recs.value?.matches ?? const [];
    final provider = matches.isEmpty ? null : matches.first.track.provider;
    final canSave =
        provider != null && ref.watch(canSavePlaylistProvider(provider));
    return Scaffold(
      extendBodyBehindAppBar: true,
      floatingActionButton: recs.hasValue ? const NewAnalysisButton() : null,
      appBar: AppBar(
        title: Text(context.tr('Your music')),
        actions: [
          if (canSave)
            IconButton(
              tooltip: context.tr(
                provider == MusicProvider.appleMusic
                    ? 'Save as Apple Music playlist'
                    : 'Save as Spotify playlist',
              ),
              icon: const Icon(Icons.playlist_add),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final lang = context.languageCode;
                final result = await ref
                    .read(playlistControllerProvider.notifier)
                    .saveAll([for (final m in recs.value!.matches) m.track]);
                messenger.showSnackBar(
                  SnackBar(content: Text(result.wordedIn(lang))),
                );
              },
            ),
          if (!canSave && matches.isNotEmpty)
            IconButton(
              tooltip: context.tr('Export to Spotify'),
              icon: const Icon(Icons.queue_music),
              onPressed: () =>
                  showExportSheet(context, [for (final m in matches) m.track]),
            ),
          IconButton(
            tooltip: context.tr('Settings'),
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: context.tr('Regenerate'),
            onPressed: recs.hasValue
                ? ref.read(recommendationsProvider.notifier).regenerate
                : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(
          child: switch (recs) {
            AsyncData(:final value) => _ResultsBody(recs: value),
            AsyncError() => _Message(
              icon: Icons.error_outline,
              text: 'We could not load songs right now.',
              action: TextButton(
                onPressed: () => ref.invalidate(recommendationsProvider),
                child: Text(context.tr('Try again')),
              ),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}

class _ResultsBody extends ConsumerWidget {
  const _ResultsBody({required this.recs});
  final Recommendations recs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filter = ref.watch(resultFilterProvider);
    final year = ref.watch(currentYearProvider);
    final ctx = ref.watch(matchContextProvider);
    final visible = filter.apply(recs.matches, currentYear: year);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverList.list(
            children: [
              _ContextSummary(ctx: ctx),
              const FeedbackInvite(),
              if (recs.isDemo) ...[
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.science_outlined),
                    title: Text(context.tr('Demo mode')),
                    subtitle: Text(
                      context.tr(
                        '{source}. Connect Spotify or Apple Music for real '
                        'catalogue search.',
                        {'source': context.tr(recs.sourceLabel)},
                      ),
                    ),
                  ),
                ),
              ],
              if (recs.notice case final notice?) ...[
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(context.tr(recs.sourceLabel)),
                    subtitle: Text(context.tr(notice)),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'Match scores estimate how well a song fits what you told us. '
                  'They are not a scientific measure of emotion.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (recs.matches.isNotEmpty &&
                  !ref.watch(
                    canSavePlaylistProvider(recs.matches.first.track.provider),
                  )) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => showExportSheet(context, [
                    for (final m in recs.matches) m.track,
                  ]),
                  icon: const Icon(Icons.queue_music),
                  label: Text(context.tr('Make this a Spotify playlist')),
                ),
              ],
              const SizedBox(height: 12),
              _Filters(matches: recs.matches, filter: filter, year: year),
            ],
          ),
        ),
        if (visible.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _Message(
              icon: Icons.filter_alt_off_outlined,
              text: recs.matches.isEmpty
                  ? 'No songs fit these settings. Try allowing explicit '
                        'content or changing your preferences.'
                  : 'No songs match this filter.',
              action: recs.matches.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () => ref
                          .read(resultFilterProvider.notifier)
                          .set(const ResultFilter()),
                      child: Text(context.tr('Clear filters')),
                    ),
            ),
          )
        else
          SliverPadding(
            // Room at the bottom so the last song clears the button.
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            sliver: SliverList.separated(
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => TrackCard(
                // Keyed so a removed card doesn't hand its state to the next.
                key: ValueKey(visible[i].track.id),
                match: visible[i],
                onTap: () => context.push(AppRoutes.track(visible[i].track.id)),
                onDislike: () =>
                    dislikeTrack(context, ref, visible[i].track.id),
              ),
            ),
          ),
      ],
    );
  }
}

class _ContextSummary extends StatelessWidget {
  const _ContextSummary({required this.ctx});
  final MatchContext ctx;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String tag(String name) =>
        context.tr(name[0].toUpperCase() + name.substring(1));
    final moods = [
      for (final m in Mood.values)
        if (ctx.mood.moods.contains(m)) context.tr(m.label),
    ];
    final scene = ctx.scene;
    final sceneText = scene == null
        ? context.tr('no photo analysis')
        : [
            for (final a in scene.atmosphere) tag(a.name),
            for (final c in scene.cues) tag(c.name),
          ].take(3).join(', ');
    final parts = [
      moods.isEmpty ? context.tr('no mood set') : moods.join(', '),
      if (ctx.activity case final activity?) context.tr(activity.label),
      if (sceneText.isNotEmpty) sceneText,
    ];
    return Row(
      children: [
        Expanded(
          child: Text(
            context.tr('For: {what}', {'what': parts.join(' · ')}),
            style: theme.textTheme.titleSmall,
          ),
        ),
        TextButton.icon(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (_) => const _AdjustMoodSheet(),
          ),
          icon: const Icon(Icons.tune, size: 18),
          label: Text(context.tr('Adjust mood')),
        ),
      ],
    );
  }
}

class _AdjustMoodSheet extends ConsumerWidget {
  const _AdjustMoodSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final input = ref.watch(moodControllerProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('How are you feeling now?'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in Mood.values)
                  FilterChip(
                    label: Text(context.tr(m.label)),
                    selected: input.moods.contains(m),
                    // Keep at least one mood selected.
                    onSelected:
                        input.moods.length == 1 && input.moods.contains(m)
                        ? null
                        : (_) => ref
                              .read(moodControllerProvider.notifier)
                              .toggle(m),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('Done')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Filters extends ConsumerWidget {
  const _Filters({
    required this.matches,
    required this.filter,
    required this.year,
  });

  final List<TrackMatch> matches;
  final ResultFilter filter;
  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(resultFilterProvider.notifier);
    final hasRecent = matches.any((m) => ResultFilter.isRecent(m.track, year));
    final genres = [
      for (final g in Genre.values)
        if (matches.any((m) => m.track.genres.contains(g))) g,
    ];
    final languages = [
      for (final l in MusicLanguage.values)
        if (matches.any((m) => m.track.language == l)) l,
    ];

    Widget row(List<Widget> chips) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final c in chips)
            Padding(padding: const EdgeInsets.only(right: 8), child: c),
        ],
      ),
    );

    return Column(
      children: [
        row([
          for (final q in QuickFilter.values)
            if (q != QuickFilter.recent || hasRecent)
              ChoiceChip(
                label: Text(context.tr(q.label)),
                selected: filter.quick == q,
                onSelected: (_) => ctrl.set(filter.copyWith(quick: q)),
              ),
        ]),
        if (genres.length > 1) ...[
          const SizedBox(height: 8),
          row([
            ChoiceChip(
              label: Text(context.tr('All genres')),
              selected: filter.genre == null,
              onSelected: (_) => ctrl.set(filter.copyWith(genre: () => null)),
            ),
            for (final g in genres)
              ChoiceChip(
                label: Text(context.tr(g.label)),
                selected: filter.genre == g,
                onSelected: (_) => ctrl.set(filter.copyWith(genre: () => g)),
              ),
          ]),
        ],
        if (languages.length > 1) ...[
          const SizedBox(height: 8),
          row([
            ChoiceChip(
              label: Text(context.tr('Any language')),
              selected: filter.language == null,
              onSelected: (_) =>
                  ctrl.set(filter.copyWith(language: () => null)),
            ),
            for (final l in languages)
              ChoiceChip(
                label: Text(context.tr(l.label)),
                selected: filter.language == l,
                onSelected: (_) => ctrl.set(filter.copyWith(language: () => l)),
              ),
          ]),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 12),
          Text(context.tr(text), textAlign: TextAlign.center),
          ?action,
        ],
      ),
    ),
  );
}
