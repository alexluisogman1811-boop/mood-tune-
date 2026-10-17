import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/match_scorer.dart';
import '../domain/track.dart';
import 'track_source.dart';

/// A small built-in catalogue of real songs whose mood features (valence,
/// energy, popularity, atmosphere tags) were estimated by hand. Used when no
/// music service is connected so the app is still usable.
class DemoTrackSource implements TrackSource {
  DemoTrackSource({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const assetPath = 'assets/demo/demo_catalog.json';

  final AssetBundle _bundle;
  List<Track>? _cache;

  @override
  String get label => 'Demo catalogue (hand-estimated features)';

  @override
  bool get isDemo => true;

  @override
  String? get notice => null;

  @override
  Future<List<Track>> candidates(MatchContext ctx) async =>
      _cache ??= parse(await _bundle.loadString(assetPath));

  /// Skips malformed entries instead of failing the whole catalogue.
  static List<Track> parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map || decoded['tracks'] is! List) {
      throw const InvalidResponseFailure('Demo catalogue is malformed.');
    }
    return [for (final entry in decoded['tracks'] as List) ?_tryParse(entry)];
  }

  static Track? _tryParse(Object? entry) {
    try {
      return Track.fromJson(entry, provider: MusicProvider.demo);
    } on InvalidResponseFailure {
      return null;
    }
  }
}
