/// What the user is about to read. Each kind sets the energy that suits it
/// and whether songs without lyrics are preferred, since words in the music
/// compete with words on the page. Heuristics, not research results.
enum ReadingKind {
  story(
    'A story or novel',
    'Gentle background music that lets the story lead.',
    targetEnergy: 30,
    preferInstrumental: true,
    reason: 'good for reading a story',
  ),
  study(
    'Studying',
    'Calm, steady music without lyrics to help you focus.',
    targetEnergy: 25,
    preferInstrumental: true,
    reason: 'helps you focus while studying',
  ),
  comics(
    'Comics or manga',
    'Livelier music; lyrics are fine with pictures.',
    targetEnergy: 55,
    preferInstrumental: false,
    reason: 'has the pace for comics',
  ),
  poetry(
    'Poetry',
    'Quiet, slow music that leaves room for every line.',
    targetEnergy: 15,
    preferInstrumental: true,
    reason: 'is quiet enough for poetry',
  ),
  articles(
    'News or articles',
    'Light, even music for quick reading.',
    targetEnergy: 40,
    preferInstrumental: true,
    reason: 'keeps an even pace for articles',
  ),
  other(
    'Something else',
    'Easy music to read along to.',
    targetEnergy: 35,
    preferInstrumental: true,
    reason: 'is easy to read along to',
  );

  const ReadingKind(
    this.label,
    this.description, {
    required this.targetEnergy,
    required this.preferInstrumental,
    required this.reason,
  });

  final String label;
  final String description;

  /// Track energy (0–100) that suits this kind of reading.
  final int targetEnergy;

  /// True when songs without lyrics should be favoured.
  final bool preferInstrumental;

  /// Explanation fragment, e.g. "is quiet enough for poetry".
  final String reason;
}
