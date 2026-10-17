import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/image_analysis/image_analysis_providers.dart';
import '../../camera/application/captured_photo_controller.dart';
import '../domain/atmosphere_analyzer.dart';

final atmosphereAnalyzerProvider = Provider<AtmosphereAnalyzer>(
  (ref) => AtmosphereAnalyzer(
    local: ref.watch(onDeviceImageAnalysisProvider),
    remote: ref.watch(remoteImageAnalysisProvider),
  ),
);

sealed class AnalysisState {
  const AnalysisState();
}

class AnalysisIdle extends AnalysisState {
  const AnalysisIdle();
}

class AnalysisRunning extends AnalysisState {
  const AnalysisRunning({required this.remote});

  /// Whether the photo is being sent to the backend (shown to the user).
  final bool remote;
}

class AnalysisDone extends AnalysisState {
  const AnalysisDone(this.outcome);
  final AnalysisOutcome outcome;
}

final analysisControllerProvider =
    NotifierProvider<AnalysisController, AnalysisState>(AnalysisController.new);

class AnalysisController extends Notifier<AnalysisState> {
  @override
  AnalysisState build() => const AnalysisIdle();

  Future<void> run({required bool allowRemote}) async {
    if (state is AnalysisRunning) return;
    final analyzer = ref.read(atmosphereAnalyzerProvider);
    final photo = ref.read(capturedPhotoProvider)?.bytes;
    final useRemote = photo != null && allowRemote && analyzer.remoteAvailable;

    state = AnalysisRunning(remote: useRemote);
    final outcome = await analyzer.analyze(photo, allowRemote: useRemote);
    if (!ref.mounted) return;
    state = AnalysisDone(outcome);
  }

  void reset() => state = const AnalysisIdle();
}
