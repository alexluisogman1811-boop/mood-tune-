import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../activity/application/activity_controller.dart';
import '../../atmosphere/application/analysis_controller.dart';
import '../../camera/application/captured_photo_controller.dart';
import '../../mood/application/mood_controller.dart';
import '../application/recommendations_controller.dart';

/// Starts over in one tap: forgets this session's activity, photo, scene
/// analysis and mood, then opens "What are you doing?". Saved music
/// preferences, language, dislikes and settings are kept.
void startNewAnalysis(BuildContext context, WidgetRef ref) {
  ref.read(activityProvider.notifier).reset();
  ref.read(capturedPhotoProvider.notifier).clear();
  ref.read(analysisControllerProvider.notifier).reset();
  ref.read(moodControllerProvider.notifier).reset();
  ref.invalidate(resultFilterProvider);
  // Back from the activity screen leads home, not to the old results.
  context.go(AppRoutes.welcome);
  context.push(AppRoutes.activity);
}

/// The floating "New analysis" button on the results screen.
class NewAnalysisButton extends ConsumerWidget {
  const NewAnalysisButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      heroTag: 'new-analysis',
      onPressed: () => startNewAnalysis(context, ref),
      icon: const Icon(Icons.auto_awesome),
      label: Text(context.tr('New analysis')),
      tooltip: context.tr('Start again with a new activity, photo and mood'),
    );
  }
}
