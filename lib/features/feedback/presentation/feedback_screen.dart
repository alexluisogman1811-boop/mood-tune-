import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../application/feedback_controller.dart';
import '../domain/feedback.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  int? _overall;
  int? _songMatch;
  int? _ease;
  final _improvements = <Improvement>{};
  Recommend? _recommend;
  final _comment = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final overall = _overall;
    if (overall == null || _sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final lang = context.languageCode;
    final text = _comment.text.trim();
    final outcome = await ref
        .read(feedbackPromptProvider.notifier)
        .submit(
          FeedbackAnswer(
            overall: overall,
            songMatch: _songMatch,
            easeOfUse: _ease,
            improvements: _improvements,
            comment: text.isEmpty ? null : text,
            recommend: _recommend,
          ),
          language: lang,
        );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          translate(switch (outcome) {
            FeedbackOutcome.sent => 'Thank you! Your feedback was sent.',
            FeedbackOutcome.savedForLater =>
              'Thank you! Your feedback is saved and will be sent later.',
          }, lang),
        ),
      ),
    );
    if (!mounted) return;
    // Opened from a link there is nothing to go back to: go home instead.
    context.canPop() ? context.pop() : context.go(AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget heading(String text, [String? hint]) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr(text), style: theme.textTheme.titleMedium),
          if (hint != null)
            Text(
              context.tr(hint),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(context.tr('Feedback'))),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Text(
                context.tr('How is MoodScape so far?'),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(
                  'Your answers are anonymous: no name, photo or song list '
                  'is sent.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              heading('Overall rating'),
              StarRating(
                value: _overall,
                onChanged: (v) => setState(() => _overall = v),
                size: 40,
              ),
              heading('Do the songs fit you?', 'Optional'),
              StarRating(
                value: _songMatch,
                onChanged: (v) => setState(() => _songMatch = v),
              ),
              heading('Is the app easy to use?', 'Optional'),
              StarRating(
                value: _ease,
                onChanged: (v) => setState(() => _ease = v),
              ),
              heading('What should we improve?', 'Pick any.'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final i in Improvement.values)
                    FilterChip(
                      label: Text(context.tr(i.label)),
                      selected: _improvements.contains(i),
                      onSelected: (on) => setState(
                        () =>
                            on ? _improvements.add(i) : _improvements.remove(i),
                      ),
                    ),
                ],
              ),
              heading('Would you recommend MoodScape to a friend?'),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<Recommend>(
                  showSelectedIcon: false,
                  emptySelectionAllowed: true,
                  segments: [
                    for (final r in Recommend.values)
                      ButtonSegment(value: r, label: Text(context.tr(r.label))),
                  ],
                  selected: {?_recommend},
                  onSelectionChanged: (s) =>
                      setState(() => _recommend = s.isEmpty ? null : s.first),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _comment,
                maxLength: FeedbackAnswer.maxCommentLength,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.tr('Anything else you want to tell us?'),
                  helperText: context.tr('Optional'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _overall == null || _sending ? null : _send,
                child: Text(context.tr('Send feedback')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Five tappable stars. Each star is a 48 dp button with a spoken label.
class StarRating extends StatelessWidget {
  const StarRating({
    required this.value,
    required this.onChanged,
    this.size = 32,
    super.key,
  });

  final int? value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final v = value ?? 0;
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            tooltip: context.tr('{count} of 5 stars', {'count': i}),
            iconSize: size,
            isSelected: i <= v,
            onPressed: () => onChanged(i),
            icon: Icon(
              i <= v ? Icons.star_rounded : Icons.star_outline_rounded,
              color: i <= v ? color : null,
            ),
          ),
      ],
    );
  }
}
