import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_theme.dart';

/// Full-bleed atmospheric gradient used behind most screens.
class GradientBackground extends StatelessWidget {
  const GradientBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.backgroundGradient : null,
        color: isDark ? null : Theme.of(context).colorScheme.surface,
      ),
      // Transparent Material so ink splashes of list tiles and buttons are
      // painted above the gradient instead of hidden beneath it.
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}
