import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../storage/storage_providers.dart';

/// The language the user picked in Settings. [system] follows the phone.
enum AppLanguage {
  system(null),
  english(Locale('en')),
  thai(Locale('th'));

  const AppLanguage(this.locale);

  /// Null means "use the device language".
  final Locale? locale;

  static const supportedLocales = [Locale('en'), Locale('th')];
}

final appLanguageProvider =
    NotifierProvider<AppLanguageController, AppLanguage>(
      AppLanguageController.new,
    );

class AppLanguageController extends Notifier<AppLanguage> {
  static const storageKey = 'settings.language';

  @override
  AppLanguage build() {
    final name = ref.read(sharedPreferencesProvider).getString(storageKey);
    return AppLanguage.values.firstWhere(
      (l) => l.name == name,
      orElse: () => AppLanguage.system,
    );
  }

  Future<void> set(AppLanguage language) async {
    state = language;
    await ref
        .read(sharedPreferencesProvider)
        .setString(storageKey, language.name);
  }
}
