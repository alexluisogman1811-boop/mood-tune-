import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../application/mood_controller.dart';
import '../domain/mood.dart';

class MoodScreen extends ConsumerStatefulWidget {
  const MoodScreen({super.key});

  @override
  ConsumerState<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends ConsumerState<MoodScreen> {
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(
      text: ref.read(moodControllerProvider).description ?? '',
    );
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final input = ref.watch(moodControllerProvider);
    final controller = ref.read(moodControllerProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(context.tr('Your mood'))),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Text(
                context.tr('How are you feeling right now?'),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('Pick one or more.'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final mood in Mood.values)
                    FilterChip(
                      label: Text(context.tr(mood.label)),
                      selected: input.moods.contains(mood),
                      onSelected: (_) => controller.toggle(mood),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              _IntensitySection(
                intensity: input.intensity,
                onChanged: controller.setIntensity,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _description,
                onChanged: controller.setDescription,
                maxLength: MoodInput.maxDescriptionLength,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.tr('Describe your mood in your own words'),
                  helperText: context.tr(
                    input.moods.contains(Mood.other)
                        ? 'Optional, but it helps us understand "Other".'
                        : 'Optional. No need to share anything personal.',
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: input.isComplete
                    ? () => context.push(AppRoutes.preferences)
                    : null,
                child: Text(context.tr('Continue')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntensitySection extends StatelessWidget {
  const _IntensitySection({required this.intensity, required this.onChanged});

  final int? intensity;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSet = intensity != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr('Intensity (optional): {value}', {
                  'value': isSet ? '$intensity / 5' : context.tr('not set'),
                }),
                style: theme.textTheme.titleSmall,
              ),
            ),
            if (isSet)
              TextButton(
                onPressed: () => onChanged(null),
                child: Text(context.tr('Clear')),
              ),
          ],
        ),
        Slider(
          value: (intensity ?? 3).toDouble(),
          min: MoodInput.minIntensity.toDouble(),
          max: MoodInput.maxIntensity.toDouble(),
          divisions: MoodInput.maxIntensity - MoodInput.minIntensity,
          label: isSet ? '$intensity' : null,
          semanticFormatterCallback: (v) =>
              context.tr('Intensity {value} of 5', {'value': v.round()}),
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}
