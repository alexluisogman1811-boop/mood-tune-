import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n/app_language.dart';
import '../features/settings/application/theme_controller.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class MoodScapeApp extends ConsumerWidget {
  const MoodScapeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'MoodScape',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      // Null follows the phone's language; unsupported ones fall back to
      // English, the first entry.
      locale: ref.watch(appLanguageProvider).locale,
      supportedLocales: AppLanguage.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
    );
  }
}
