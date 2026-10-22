import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/l10n/app_language.dart';
import '../../account/application/account_providers.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/widgets/gradient_background.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _steps = [
    (Icons.directions_run, 'Tell us what you are doing'),
    (Icons.photo_camera_outlined, 'Snap your surroundings (optional)'),
    (Icons.favorite_outline, 'Tell us how you feel'),
    (Icons.queue_music_outlined, 'Get a playlist for the moment'),
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
                        const _LanguageButton(),
                        const _AccountButton(),
                        IconButton(
                          tooltip: context.tr('Settings'),
                          onPressed: () => context.push(AppRoutes.settings),
                          icon: const Icon(Icons.settings_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text('MoodScape', style: theme.textTheme.displaySmall),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(
                        'Music for every moment: what you do, how you '
                        'feel and where you are.',
                      ),
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
                                context.tr(label),
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
                                context.tr(
                                  'Photos describe the scene, not you. Nothing '
                                  'is uploaded without your consent, and you '
                                  'can always continue without a photo.',
                                ),
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: () => context.push(AppRoutes.activity),
                      child: Text(context.tr('Get Started')),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => context.push(AppRoutes.privacy),
                        child: Text(context.tr('How we handle your photos')),
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

/// Opens the account page; hidden when accounts are switched off.
class _AccountButton extends ConsumerWidget {
  const _AccountButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(accountsEnabledProvider)) return const SizedBox.shrink();
    return IconButton(
      tooltip: context.tr('Your account'),
      onPressed: () => context.push(AppRoutes.account),
      icon: const Icon(Icons.account_circle_outlined),
    );
  }
}

/// One tap between English and Thai; Settings also offers "System".
class _LanguageButton extends ConsumerWidget {
  const _LanguageButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thai = context.languageCode == 'th';
    return TextButton.icon(
      onPressed: () => ref
          .read(appLanguageProvider.notifier)
          .set(thai ? AppLanguage.english : AppLanguage.thai),
      icon: const Icon(Icons.translate, size: 18),
      // Each language is named in its own words.
      label: Text(
        thai ? 'English' : 'ไทย',
        semanticsLabel: thai ? 'Switch to English' : 'เปลี่ยนเป็นภาษาไทย',
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.tr('MoodScape logo'),
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
