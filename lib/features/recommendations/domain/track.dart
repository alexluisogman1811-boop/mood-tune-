import '../../../core/errors/app_failure.dart';
import '../../../services/image_analysis/scene_features.dart';
import '../../preferences/domain/music_preferences.dart';

enum MusicProvider { spotify, appleMusic, demo }

/// A candidate song plus whatever matching features are known about it.
/// Every feature is nullable: unknown is different from zero.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.provider,
    this.providerUri,
    this.album,
    this.artworkUrl,
    this.previewUrl,
    this.externalUrl,
    this.releaseYear,
    this.genres = const {},
    this.language,
    this.isInstrumental,
    this.isExplicit,
    this.valence,
    this.energy,
    this.popularity,
    this.atmosphere,
    this.cues,
  });

  final String id;
  final String title;
  final String artist;
  final MusicProvider provider;

  /// Provider-specific identifier used for playlist edits
  /// (e.g. `spotify:track:…`).
  final String? providerUri;
  final String? album;
  final Uri? artworkUrl;
  final Uri? previewUrl;

  /// Deep link to the track in its provider, when known.
  final Uri? externalUrl;
  final int? releaseYear;
  final Set<Genre> genres;
  final MusicLanguage? language;
  final bool? isInstrumental;
  final bool? isExplicit;

  /// 0 (sad/dark) – 100 (happy/bright).
  final int? valence;

  /// 0 (very calm) – 100 (very intense).
  final int? energy;

  /// 0 (obscure) – 100 (very well known).
  final int? popularity;

  /// Scene atmospheres the song suits; null when unknown.
  final Set<SceneAtmosphere>? atmosphere;
  final Set<EnvironmentalCue>? cues;

  /// Parses a catalogue entry. Throws [InvalidResponseFailure] when required
  /// fields are missing or numeric features are out of range.
  factory Track.fromJson(Object? json, {required MusicProvider provider}) {
    if (json is! Map) throw const InvalidResponseFailure();
    String req(String key) {
      final v = json[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      throw InvalidResponseFailure('Track is missing "$key".');
    }

    int? score(String key) {
      final v = json[key];
      if (v == null) return null;
      if (v is num && v.isFinite && v >= 0 && v <= 100) return v.round();
      throw InvalidResponseFailure('Track "$key" is out of range.');
    }

    Set<T>? names<T extends Enum>(List<T> values, String key) {
      final raw = json[key];
      if (raw is! List) return null;
      return {
        for (final n in raw)
          for (final v in values)
            if (v.name == n) v,
      };
    }

    T? one<T extends Enum>(List<T> values, Object? n) {
      for (final v in values) {
        if (v.name == n) return v;
      }
      return null;
    }

    final year = json['year'];
    return Track(
      id: req('id'),
      title: req('title'),
      artist: req('artist'),
      provider: provider,
      album: json['album'] is String ? json['album'] as String : null,
      releaseYear: year is int && year > 1800 && year < 2200 ? year : null,
      genres: names(Genre.values, 'genres') ?? const {},
      language: one(MusicLanguage.values, json['language']),
      isInstrumental: json['instrumental'] is bool
          ? json['instrumental'] as bool
          : null,
      isExplicit: json['explicit'] is bool ? json['explicit'] as bool : null,
      valence: score('valence'),
      energy: score('energy'),
      popularity: score('popularity'),
      atmosphere: names(SceneAtmosphere.values, 'atmosphere'),
      cues: names(EnvironmentalCue.values, 'cues'),
    );
  }
}
