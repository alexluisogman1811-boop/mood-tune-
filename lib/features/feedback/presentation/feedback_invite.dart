import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../application/feedback_controller.dart';

/// After a day of use, invites the user to rate the app. Easy to dismiss.
class FeedbackInvite extends ConsumerWidget {
  const FeedbackInvite({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(feedbackPromptProvider)) return const SizedBox.shrink();
    // The app theme makes filled buttons full width; in a row they must
    // size to their label instead.
    const compact = Size(0, 48);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.rate_review_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr(
                        'You have used MoodScape for a day. How is it going?',
                      ),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Side by side when they fit; stacked on narrow screens.
              OverflowBar(
                alignment: MainAxisAlignment.end,
                overflowAlignment: OverflowBarAlignment.end,
                spacing: 8,
                overflowSpacing: 4,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(minimumSize: compact),
                    onPressed: () =>
                        ref.read(feedbackPromptProvider.notifier).snooze(),
                    child: Text(context.tr('Later')),
                  ),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(minimumSize: compact),
                    onPressed: () => context.push(AppRoutes.feedback),
                    icon: const Icon(Icons.star_rounded),
                    label: Text(context.tr('Rate MoodScape')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
