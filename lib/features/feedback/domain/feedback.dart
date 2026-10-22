/// What could be better, as chosen on the feedback screen.
enum Improvement {
  moreSongs('More songs'),
  betterMatches('Better song choices'),
  moreLanguages('More languages'),
  moreActivities('More activities'),
  photo('Photo analysis'),
  spotify('Saving to Spotify'),
  design('Look and design'),
  speed('Speed');

  const Improvement(this.label);
  final String label;
}

enum Recommend {
  yes('Yes'),
  maybe('Maybe'),
  no('No');

  const Recommend(this.label);
  final String label;
}

/// One person's feedback. Anonymous: no name, photo, mood or song list.
class FeedbackAnswer {
  const FeedbackAnswer({
    required this.overall,
    this.songMatch,
    this.easeOfUse,
    this.improvements = const {},
    this.comment,
    this.recommend,
  }) : assert(overall >= 1 && overall <= 5);

  static const maxCommentLength = 500;

  /// 1–5 stars.
  final int overall;

  /// 1–5: how well the songs fitted. Null when skipped.
  final int? songMatch;

  /// 1–5: how easy the app was to use. Null when skipped.
  final int? easeOfUse;
  final Set<Improvement> improvements;
  final String? comment;
  final Recommend? recommend;

  Map<String, Object?> toJson({
    required String installId,
    required String language,
    required String platform,
    required String appVersion,
  }) => {
    'overall': overall,
    'songMatch': songMatch,
    'easeOfUse': easeOfUse,
    'improvements': [for (final i in improvements) i.name],
    'comment': comment,
    'recommend': recommend?.name,
    'installId': installId,
    'language': language,
    'platform': platform,
    'appVersion': appVersion,
  };
}
