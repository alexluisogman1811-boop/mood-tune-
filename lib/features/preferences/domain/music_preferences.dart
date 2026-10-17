enum Genre {
  pop('Pop'),
  rock('Rock'),
  hipHop('Hip-hop'),
  rnb('R&B'),
  soul('Soul'),
  electronic('Electronic'),
  jazz('Jazz'),
  classical('Classical'),
  indie('Indie'),
  folk('Folk'),
  lofi('Lo-fi'),
  ambient('Ambient'),
  latin('Latin'),
  kpop('K-pop'),
  soundtrack('Soundtrack'),
  country('Country');

  const Genre(this.label);
  final String label;
}

enum MusicLanguage {
  english('English'),
  spanish('Spanish'),
  korean('Korean'),
  japanese('Japanese'),
  french('French'),
  portuguese('Portuguese');

  const MusicLanguage(this.label);
  final String label;
}

enum VocalPreference {
  any('No preference'),
  instrumental('Instrumental'),
  vocal('With vocals');

  const VocalPreference(this.label);
  final String label;
}

enum DiscoveryPreference {
  familiar('Familiar songs'),
  balanced('A mix'),
  discover('New discoveries');

  const DiscoveryPreference(this.label);
  final String label;
}

enum EnergyPreference {
  relaxing('Relaxing', 25),
  balanced('Balanced', 50),
  energetic('Energetic', 80);

  const EnergyPreference(this.label, this.target);
  final String label;

  /// Target track energy on the 0–100 scale.
  final int target;
}

T? _byName<T extends Enum>(List<T> values, Object? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

/// Listening preferences. The default value means "the user skipped this".
class MusicPreferences {
  const MusicPreferences({
    this.genres = const {},
    this.languages = const {},
    this.vocal = VocalPreference.any,
    this.discovery = DiscoveryPreference.balanced,
    this.energy,
    this.allowExplicit = true,
    this.playlistLength = 20,
  });

  static const playlistLengths = [10, 20, 30];

  final Set<Genre> genres;

  /// Empty means any language.
  final Set<MusicLanguage> languages;
  final VocalPreference vocal;
  final DiscoveryPreference discovery;

  /// Null means no explicit energy request.
  final EnergyPreference? energy;
  final bool allowExplicit;
  final int playlistLength;

  /// True when at least one taste preference (not energy) is set.
  bool get hasTastePreferences =>
      genres.isNotEmpty ||
      languages.isNotEmpty ||
      vocal != VocalPreference.any ||
      discovery != DiscoveryPreference.balanced;

  MusicPreferences copyWith({
    Set<Genre>? genres,
    Set<MusicLanguage>? languages,
    VocalPreference? vocal,
    DiscoveryPreference? discovery,
    EnergyPreference? Function()? energy,
    bool? allowExplicit,
    int? playlistLength,
  }) => MusicPreferences(
    genres: genres ?? this.genres,
    languages: languages ?? this.languages,
    vocal: vocal ?? this.vocal,
    discovery: discovery ?? this.discovery,
    energy: energy != null ? energy() : this.energy,
    allowExplicit: allowExplicit ?? this.allowExplicit,
    playlistLength: playlistLength ?? this.playlistLength,
  );

  Map<String, Object?> toJson() => {
    'genres': [for (final g in genres) g.name],
    'languages': [for (final l in languages) l.name],
    'vocal': vocal.name,
    'discovery': discovery.name,
    'energy': energy?.name,
    'allowExplicit': allowExplicit,
    'playlistLength': playlistLength,
  };

  /// Tolerant of stored data from older versions: anything unreadable
  /// falls back to the default for that field.
  factory MusicPreferences.fromJson(Object? json) {
    if (json is! Map) return const MusicPreferences();
    Set<T> set<T extends Enum>(List<T> values, Object? raw) => {
      if (raw is List)
        for (final n in raw) ?_byName(values, n),
    };
    final length = json['playlistLength'];
    return MusicPreferences(
      genres: set(Genre.values, json['genres']),
      languages: set(MusicLanguage.values, json['languages']),
      vocal:
          _byName(VocalPreference.values, json['vocal']) ?? VocalPreference.any,
      discovery:
          _byName(DiscoveryPreference.values, json['discovery']) ??
          DiscoveryPreference.balanced,
      energy: _byName(EnergyPreference.values, json['energy']),
      allowExplicit: json['allowExplicit'] is bool
          ? json['allowExplicit'] as bool
          : true,
      playlistLength: playlistLengths.contains(length) ? length as int : 20,
    );
  }
}
