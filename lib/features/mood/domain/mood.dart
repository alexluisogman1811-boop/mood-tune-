/// Self-reported moods. Each mood carries rough valence/energy coordinates
/// (0–100) that the matching algorithm uses as structured features. These are
/// heuristics for music compatibility, not a model of real emotions.
enum Mood {
  happy('Happy', valence: 85, energy: 70),
  calm('Calm', valence: 65, energy: 25),
  sad('Sad', valence: 20, energy: 25),
  stressed('Stressed', valence: 30, energy: 70),
  tired('Tired', valence: 40, energy: 15),
  motivated('Motivated', valence: 75, energy: 85),
  romantic('Romantic', valence: 75, energy: 40),
  nostalgic('Nostalgic', valence: 50, energy: 35),
  lonely('Lonely', valence: 25, energy: 30),
  excited('Excited', valence: 85, energy: 90),
  focused('Focused', valence: 55, energy: 50),
  other('Other', valence: null, energy: null);

  const Mood(this.label, {required this.valence, required this.energy});

  final String label;

  /// Null for [Mood.other], whose meaning comes from the user's own words.
  final int? valence;
  final int? energy;
}

/// What the user told us about how they feel. Immutable.
class MoodInput {
  const MoodInput({this.moods = const {}, this.intensity, this.description});

  static const minIntensity = 1;
  static const maxIntensity = 5;
  static const maxDescriptionLength = 200;

  final Set<Mood> moods;

  /// Optional 1–5 strength; null means the user did not set it.
  final int? intensity;

  /// Optional free text, trimmed; null when empty.
  final String? description;

  bool get isComplete => moods.isNotEmpty;

  MoodInput copyWith({
    Set<Mood>? moods,
    int? Function()? intensity,
    String? Function()? description,
  }) => MoodInput(
    moods: moods ?? this.moods,
    intensity: intensity != null ? intensity() : this.intensity,
    description: description != null ? description() : this.description,
  );

  @override
  bool operator ==(Object other) =>
      other is MoodInput &&
      other.intensity == intensity &&
      other.description == description &&
      other.moods.length == moods.length &&
      other.moods.containsAll(moods);

  @override
  int get hashCode =>
      Object.hash(Object.hashAllUnordered(moods), intensity, description);
}
