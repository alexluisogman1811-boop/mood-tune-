import '../domain/match_scorer.dart';
import '../domain/track.dart';

/// Supplies candidate tracks. Implemented by the demo catalogue now and by
/// the Spotify / Apple Music services later.
abstract interface class TrackSource {
  /// Shown to the user so they know where results come from.
  String get label;

  /// True when results do not come from a connected music service.
  bool get isDemo;

  /// Optional caveat shown above results (e.g. how features were derived).
  String? get notice;

  Future<List<Track>> candidates(MatchContext ctx);
}
