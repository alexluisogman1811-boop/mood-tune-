import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/configuration/config_provider.dart';
import '../../core/network/dio_provider.dart';
import 'image_analysis_service.dart';
import 'on_device_image_analysis_service.dart';
import 'remote_image_analysis_service.dart';

/// Null when no HTTPS analysis backend is configured.
final remoteImageAnalysisProvider = Provider<ImageAnalysisService?>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.hasAnalysisBackend) return null;
  return RemoteImageAnalysisService(
    ref.watch(dioProvider),
    baseUrl: config.analysisBackendUrl,
  );
});

final onDeviceImageAnalysisProvider = Provider<ImageAnalysisService>(
  (ref) => const OnDeviceImageAnalysisService(),
);
