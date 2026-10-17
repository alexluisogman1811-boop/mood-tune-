import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/privacy/photo_consent.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../camera/application/captured_photo_controller.dart';
import '../application/analysis_controller.dart';
import 'scene_summary_card.dart';
import 'upload_consent_dialog.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(analysisControllerProvider) is AnalysisIdle) _start();
    });
  }

  Future<void> _start() async {
    final hasPhoto = ref.read(capturedPhotoProvider) != null;
    final remoteAvailable = ref
        .read(atmosphereAnalyzerProvider)
        .remoteAvailable;
    var allowRemote = false;

    if (hasPhoto && remoteAvailable) {
      final remembered = ref.read(photoUploadConsentProvider);
      if (remembered != null) {
        allowRemote = remembered;
      } else {
        final answer = await showUploadConsentDialog(context);
        if (!mounted) return;
        allowRemote = answer.allow;
        if (answer.remember) {
          await ref.read(photoUploadConsentProvider.notifier).set(answer.allow);
        }
      }
    }
    if (!mounted) return;
    await ref
        .read(analysisControllerProvider.notifier)
        .run(allowRemote: allowRemote);
  }

  void _retry() {
    ref.read(analysisControllerProvider.notifier).reset();
    _start();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analysisControllerProvider);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Your atmosphere')),
      body: GradientBackground(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: switch (state) {
              AnalysisIdle() => const _Progress(
                key: ValueKey('idle'),
                label: 'Getting ready…',
              ),
              AnalysisRunning(:final remote) => _Progress(
                key: const ValueKey('running'),
                label: remote
                    ? 'Sending your photo for AI scene analysis…'
                    : 'Reading light and colour on your device…',
              ),
              AnalysisDone(:final outcome) => ListView(
                key: const ValueKey('done'),
                padding: const EdgeInsets.all(24),
                children: [
                  if (outcome.features case final features?)
                    SceneSummaryCard(features: features),
                  if (outcome.notice case final notice?) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: Text(notice),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.push(AppRoutes.results),
                    child: const Text('See my music'),
                  ),
                  if (outcome.usedFallback) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _retry,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Try analysis again'),
                    ),
                  ],
                ],
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatefulWidget {
  const _Progress({required this.label, super.key});
  final String label;

  @override
  State<_Progress> createState() => _ProgressState();
}

class _ProgressState extends State<_Progress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: Tween(begin: 0.9, end: 1.05).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
              ),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [AppColors.glow, AppColors.seed],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.seed.withValues(alpha: 0.5),
                      blurRadius: 40,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
