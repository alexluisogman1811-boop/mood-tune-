import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/gradient_background.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _steps = [
    (Icons.photo_camera_outlined, 'Snap your surroundings (optional)'),
    (Icons.favorite_outline, 'Tell us how you feel'),
    (Icons.queue_music_outlined, 'Get a playlist that fits the moment'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 64,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _Logo(),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Settings',
                          onPressed: () => context.push(AppRoutes.settings),
                          icon: const Icon(Icons.settings_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text('MoodScape', style: theme.textTheme.displaySmall),
                    const SizedBox(height: 8),
                    Text(
                      'Music that matches your surroundings and how you feel.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 40),
                    for (final (icon, label) in _steps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Icon(icon, color: AppColors.glow),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                label,
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Photos describe the scene, not you. Nothing '
                                'is uploaded without your consent, and you '
                                'can always continue without a photo.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: () => context.push(AppRoutes.capture),
                      child: const Text('Get Started'),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => context.push(AppRoutes.privacy),
                        child: const Text('How we handle your photos'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'MoodScape logo',
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.seed, AppColors.glow],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.seed.withValues(alpha: 0.45),
              blurRadius: 32,
            ),
          ],
        ),
        child: const Icon(Icons.graphic_eq, size: 36, color: Colors.white),
      ),
    );
  }
}
