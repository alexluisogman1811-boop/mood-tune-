import 'dart:typed_data';

import '../../../core/errors/app_failure.dart';
import '../../../services/image_analysis/image_analysis_service.dart';
import '../../../services/image_analysis/scene_features.dart';

/// Result of trying to describe the scene. [features] is null when there was
/// no photo or nothing could be analysed; recommendations then rely on mood.
class AnalysisOutcome {
  const AnalysisOutcome({
    this.features,
    this.notice,
    this.usedFallback = false,
  });

  const AnalysisOutcome.skipped()
    : features = null,
      usedFallback = false,
      notice = 'No photo — recommendations will use your mood only.';

  final SceneFeatures? features;
  final bool usedFallback;

  /// Short user-facing explanation when something did not go to plan.
  final String? notice;
}

/// Chooses remote vs on-device analysis and falls back gracefully.
class AtmosphereAnalyzer {
  const AtmosphereAnalyzer({required this.local, this.remote});

  final ImageAnalysisService local;
  final ImageAnalysisService? remote;

  bool get remoteAvailable => remote != null;

  /// [allowRemote] must reflect the user's explicit consent to upload.
  Future<AnalysisOutcome> analyze(
    Uint8List? photo, {
    required bool allowRemote,
  }) async {
    if (photo == null) return const AnalysisOutcome.skipped();

    final remote = this.remote;
    String? remoteProblem;
    if (remote != null && allowRemote) {
      try {
        return AnalysisOutcome(
          features: await remote.analyzeEnvironment(photo),
        );
      } on AppFailure catch (e) {
        remoteProblem = e.message;
      }
    }

    try {
      final features = await local.analyzeEnvironment(photo);
      return AnalysisOutcome(
        features: features,
        usedFallback: remoteProblem != null,
        notice: remoteProblem == null
            ? null
            : 'AI analysis was unavailable ($remoteProblem) so we used basic '
                  'on-device analysis instead.',
      );
    } on AppFailure catch (e) {
      return AnalysisOutcome(
        usedFallback: true,
        notice: '${e.message} Recommendations will use your mood only.',
      );
    }
  }
}
