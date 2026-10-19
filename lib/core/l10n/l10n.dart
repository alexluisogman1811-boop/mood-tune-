import 'package:material_ui/material_ui.dart';

import 'translate.dart';

export 'translate.dart';

extension L10n on BuildContext {
  /// The language the app is showing, e.g. `en` or `th`.
  String get languageCode =>
      Localizations.maybeLocaleOf(this)?.languageCode ?? 'en';

  /// [english] in the current language; see [translate].
  String tr(String english, [Map<String, Object?> args = const {}]) =>
      translate(english, languageCode, args);
}
