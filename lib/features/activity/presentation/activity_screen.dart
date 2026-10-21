import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../application/activity_controller.dart';
import '../domain/activity.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  static const _icons = {
    Activity.exercise: Icons.fitness_center,
    Activity.running: Icons.directions_run,
    Activity.party: Icons.celebration,
    Activity.tidying: Icons.cleaning_services,
    Activity.driving: Icons.directions_car,
    Activity.commuting: Icons.directions_bus,
    Activity.cooking: Icons.restaurant,
    Activity.chilling: Icons.weekend,
    Activity.working: Icons.work_outline,
    Activity.studying: Icons.school_outlined,
    Activity.reading: Icons.menu_book_outlined,
    Activity.sleeping: Icons.bedtime_outlined,
    Activity.other: Icons.more_horiz,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(activityProvider);
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(context.tr('Your activity'))),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Text(
                context.tr('What are you doing?'),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(
                  'MoodScape picks music that fits the moment, together with '
                  'your photo and how you feel.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final a in Activity.values)
                        SizedBox(
                          width: width,
                          child: _ActivityTile(
                            icon: _icons[a]!,
                            label: context.tr(a.label),
                            selected: selected == a,
                            onTap: () =>
                                ref.read(activityProvider.notifier).set(a),
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (selected != null) ...[
                const SizedBox(height: 16),
                Text(
                  context.tr(selected.description),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 20),
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

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? scheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: selected ? scheme.primary : null),
                const SizedBox(width: 10),
                Expanded(child: Text(label, maxLines: 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
