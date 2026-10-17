import 'dart:typed_data';

import 'scene_features.dart';

/// Provider-agnostic contract for describing a photographed environment.
///
/// Implementations receive an already resized JPEG and must throw an
/// `AppFailure` (never a raw exception) when analysis is impossible.
abstract interface class ImageAnalysisService {
  /// True when this implementation sends the image off the device, which
  /// requires the user's explicit consent first.
  bool get isRemote;

  Future<SceneFeatures> analyzeEnvironment(Uint8List jpegBytes);
}
