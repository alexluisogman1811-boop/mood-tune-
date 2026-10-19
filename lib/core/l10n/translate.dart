import 'thai.dart';

/// Language codes the app ships translations for. English is the source
/// language: its text lives in the code itself.
const supportedLanguageCodes = ['en', 'th'];

/// Returns [english] in the language [languageCode], filling `{name}`
/// placeholders from [args]. Text without a translation stays in English,
/// so a missing entry never breaks the UI.
///
/// Plain Dart (no Flutter), so domain code can word its output too.
String translate(
  String english,
  String languageCode, [
  Map<String, Object?> args = const {},
]) {
  final template = switch (languageCode) {
    'th' => thaiStrings[english] ?? english,
    _ => english,
  };
  if (args.isEmpty) return template;
  return template.replaceAllMapped(
    _placeholder,
    (m) => args.containsKey(m[1]) ? '${args[m[1]]}' : m[0]!,
  );
}

final _placeholder = RegExp(r'\{(\w+)\}');
