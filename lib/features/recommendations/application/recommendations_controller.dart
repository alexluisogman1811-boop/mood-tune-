import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../services/apple_music/apple_music_track_source.dart';
import '../../../services/spotify/spotify_track_source.dart';
import '../../atmosphere/application/analysis_controller.dart';
import '../../mood/application/mood_controller.dart';
import '../../music_platform/application/apple_music_providers.dart';
import '../../music_platform/application/platform_providers.dart';
import '../../preferences/application/preferences_controller.dart';
import '../data/demo_track_source.dart';
import '../data/track_source.dart';
import '../domain/match_scorer.dart';
import '../domain/recommendation_engine.dart';
import '../domain/track.dart';
import 'disliked_tracks.dart';

final demoTrackSourceProvider = Provider<TrackSource>(
  (ref) => DemoTrackSource(),
);

/// The chosen service when it can search; otherwise the demo catalogue.
/// Spotify search needs a signed-in user; Apple Music catalogue search only
/// needs a developer token, so it also works on Android with a token backend.
final trackSourceProvider = Provider<TrackSource>((ref) {
  switch (ref.watch(selectedPlatformProvider)) {
    case MusicPlatform.spotify:
      final connected =
          ref.watch(spotifyConnectionProvider).value?.connected ?? false;
      final client = ref.watch(spotifyApiClientProvider);
      if (connected && client != null) return SpotifyTrackSource(client);
    case MusicPlatform.appleMusic:
      final client = ref.watch(appleMusicApiClientProvider);
      if (client != null) {
        return AppleMusicTrackSource(
          client,
          fallbackStorefront: ref.watch(deviceStorefrontProvider),
          useUserStorefront:
              ref.watch(appleMusicConnectionProvider).value?.authorized ??
              false,
        );
      }
    case null:
      break;
  }
  return ref.watch(demoTrackSourceProvider);
});

final recommendationEngineProvider = Provider<RecommendationEngine>(
  (ref) => const RecommendationEngine(),
);

final currentYearProvider = Provider<int>((ref) => DateTime.now().year);

final matchContextProvider = Provider<MatchContext>((ref) {
  final analysis = ref.watch(analysisControllerProvider);
  return MatchContext(
    mood: ref.watch(moodControllerProvider),
    preferences: ref.watch(musicPreferencesProvider),
    scene: analysis is AnalysisDone ? analysis.outcome.features : null,
  );
});

class Recommendations {
  const Recommendations({
    required this.matches,
    required this.sourceLabel,
    required this.isDemo,
    this.notice,
  });

  final List<TrackMatch> matches;
  final String sourceLabel;
  final bool isDemo;

  /// Caveat about the source, or why we fell back to the demo catalogue.
  final String? notice;

  TrackMatch? byId(String id) {
    for (final m in matches) {
      if (m.track.id == id) return m;
    }
    return null;
  }

  Recommendations withMatches(List<TrackMatch> next) => Recommendations(
    matches: next,
    sourceLabel: sourceLabel,
    isDemo: isDemo,
    notice: notice,
  );
}

final recommendationsProvider =
    AsyncNotifierProvider<RecommendationsController, Recommendations>(
      RecommendationsController.new,
      // No automatic retries: a failing service already falls back to the
      // demo catalogue, and the screen offers an explicit "Try again".
      retry: (_, _) => null,
    );

class RecommendationsController extends AsyncNotifier<Recommendations> {
  List<Track> _candidates = const [];

  @override
  Future<Recommendations> build() async {
    final ctx = ref.watch(matchContextProvider);
    var source = ref.watch(trackSourceProvider);
    String? notice = source.notice;
    try {
      _candidates = await source.candidates(ctx);
    } on AppFailure catch (e) {
      if (source.isDemo) rethrow;
      // A connected service failed: stay useful with the demo catalogue.
      notice =
          '${source.label} is unavailable (${e.message}) — showing the '
          'demo catalogue instead.';
      source = ref.read(demoTrackSourceProvider);
      _candidates = await source.candidates(ctx);
    }
    return Recommendations(
      matches: ref
          .read(recommendationEngineProvider)
          .rank(
            _candidates,
            ctx,
            limit: ctx.preferences.playlistLength,
            // Read, not watch: dislikes update the list in place below.
            exclude: ref.read(dislikedTracksProvider),
          ),
      sourceLabel: source.label,
      isDemo: source.isDemo,
      notice: notice,
    );
  }

  /// New batch that avoids the songs currently shown where possible, and
  /// never brings back disliked songs.
  void regenerate() {
    final current = state.value;
    if (current == null) return;
    final ctx = ref.read(matchContextProvider);
    state = AsyncData(
      current.withMatches(
        ref
            .read(recommendationEngineProvider)
            .regenerate(
              _candidates,
              ctx,
              limit: ctx.preferences.playlistLength,
              shown: {for (final m in current.matches) m.track.id},
              exclude: ref.read(dislikedTracksProvider),
            ),
      ),
    );
  }

  /// "Not for me": removes [trackId], remembers the dislike, and fills the
  /// gap with the best song not already shown or disliked (if any remain).
  /// Returns null when the song isn't in the current list.
  Future<DislikeOutcome?> dislike(String trackId) async {
    final current = state.value;
    final removed = current?.byId(trackId);
    if (current == null || removed == null) return null;

    await ref.read(dislikedTracksProvider.notifier).add(trackId);
    final remaining = [
      for (final m in current.matches)
        if (m.track.id != trackId) m,
    ];
    final replacement = ref
        .read(recommendationEngineProvider)
        .rank(
          _candidates,
          ref.read(matchContextProvider),
          limit: 1,
          exclude: {
            ...ref.read(dislikedTracksProvider),
            for (final m in remaining) m.track.id,
          },
        )
        .firstOrNull;

    state = AsyncData(
      current.withMatches(
        [...remaining, ?replacement]..sort(RecommendationEngine.compare),
      ),
    );
    return DislikeOutcome(removed: removed, replacement: replacement);
  }

  /// Reverses [dislike]: forgets the dislike, restores the song and drops
  /// the replacement that was added for it.
  Future<void> undoDislike(DislikeOutcome outcome) async {
    final current = state.value;
    if (current == null) return;
    await ref
        .read(dislikedTracksProvider.notifier)
        .remove(outcome.removed.track.id);
    final replacementId = outcome.replacement?.track.id;
    state = AsyncData(
      current.withMatches(
        [
          for (final m in current.matches)
            if (m.track.id != replacementId) m,
          outcome.removed,
        ]..sort(RecommendationEngine.compare),
      ),
    );
  }
}

class DislikeOutcome {
  const DislikeOutcome({required this.removed, this.replacement});

  final TrackMatch removed;

  /// Null when the catalogue has no other suitable song left.
  final TrackMatch? replacement;
}

final resultFilterProvider =
    NotifierProvider<ResultFilterController, ResultFilter>(
      ResultFilterController.new,
    );

class ResultFilterController extends Notifier<ResultFilter> {
  @override
  ResultFilter build() => const ResultFilter();

  void set(ResultFilter filter) => state = filter;
}
