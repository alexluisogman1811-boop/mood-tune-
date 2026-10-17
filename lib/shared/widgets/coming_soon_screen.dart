import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'gradient_background.dart';

/// Honest placeholder for flows that are not built yet. When [nextRoute] is
/// given, the user can still move on through the rest of the flow.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    required this.title,
    this.nextLabel,
    this.nextRoute,
    super.key,
  });

  final String title;
  final String? nextLabel;
  final String? nextRoute;

  @override
  Widget build(BuildContext context) {
    final next = nextRoute;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      extendBodyBehindAppBar: true,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'This step is not implemented yet.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                if (next != null) ...[
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.push(next),
                    child: Text(nextLabel ?? 'Continue'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
