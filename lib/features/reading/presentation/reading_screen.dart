import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../application/reading_controller.dart';
import '../domain/reading.dart';

class ReadingScreen extends ConsumerWidget {
  const ReadingScreen({super.key});

  static const _icons = {
    ReadingKind.story: Icons.menu_book_outlined,
    ReadingKind.study: Icons.school_outlined,
    ReadingKind.comics: Icons.auto_stories_outlined,
    ReadingKind.poetry: Icons.format_quote_outlined,
    ReadingKind.articles: Icons.newspaper_outlined,
    ReadingKind.other: Icons.more_horiz,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(readingProvider);
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(context.tr('Your reading'))),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Text(
                context.tr('What are you reading?'),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(
                  'MoodScape picks music to read along to, so it helps '
                  'instead of distracting you.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              for (final kind in ReadingKind.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: selected == kind
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      selected: selected == kind,
                      leading: Icon(_icons[kind], size: 28),
                      title: Text(context.tr(kind.label)),
                      subtitle: Text(context.tr(kind.description)),
                      trailing: Icon(
                        selected == kind
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      onTap: () => ref.read(readingProvider.notifier).set(kind),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () => context.push(AppRoutes.capture),
                child: Text(context.tr('Continue')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
