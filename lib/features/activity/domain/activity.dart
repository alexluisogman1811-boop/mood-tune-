/// What the user is doing while they listen. Each activity sets the energy
/// that suits it and whether songs without lyrics are preferred (words in
/// the music compete with reading, studying and work). Heuristics, not
/// research results.
enum Activity {
  exercise(
    'Exercise or gym',
    'Strong, fast music to keep you moving.',
    targetEnergy: 90,
    reason: 'pumps you up for a workout',
  ),
  running(
    'Running',
    'A steady, quick beat to run to.',
    targetEnergy: 85,
    reason: 'keeps your running pace',
  ),
  party(
    'Party',
    'Big, danceable songs.',
    targetEnergy: 90,
    reason: 'gets the party going',
  ),
  tidying(
    'Tidying up',
    'Upbeat songs that make chores go faster.',
    targetEnergy: 75,
    reason: 'makes tidying up more fun',
  ),
  driving(
    'Driving',
    'Songs to sing along to on the road.',
    targetEnergy: 65,
    reason: 'is great for the road',
  ),
  commuting(
    'Commuting',
    'Easy songs for the bus or train.',
    targetEnergy: 55,
    reason: 'makes the trip go by',
  ),
  cooking(
    'Cooking',
    'Warm, happy music for the kitchen.',
    targetEnergy: 55,
    reason: 'is nice to cook to',
  ),
  chilling(
    'Chilling',
    'Relaxed songs to unwind.',
    targetEnergy: 30,
    reason: 'helps you unwind',
  ),
  working(
    'Working',
    'Steady music without lyrics to stay focused.',
    targetEnergy: 40,
    preferInstrumental: true,
    reason: 'helps you focus on work',
  ),
  studying(
    'Studying',
    'Calm music without lyrics to help you focus.',
    targetEnergy: 25,
    preferInstrumental: true,
    reason: 'helps you focus while studying',
  ),
  reading(
    'Reading',
    'Gentle background music that lets the words lead.',
    targetEnergy: 25,
    preferInstrumental: true,
    reason: 'is good for reading',
  ),
  sleeping(
    'Falling asleep',
    'Very quiet, slow music to drift off.',
    targetEnergy: 10,
    preferInstrumental: true,
    reason: 'is quiet enough to fall asleep to',
  ),
  other(
    'Something else',
    'Easy music for any moment.',
    targetEnergy: 45,
    reason: 'fits the moment',
  );

  const Activity(
    this.label,
    this.description, {
    required this.targetEnergy,
    required this.reason,
    this.preferInstrumental = false,
  });

  final String label;
  final String description;

  /// Track energy (0–100) that suits this activity.
  final int targetEnergy;

  /// True when songs without lyrics should be favoured.
  final bool preferInstrumental;

  /// Explanation fragment, e.g. "keeps your running pace".
  final String reason;
}
