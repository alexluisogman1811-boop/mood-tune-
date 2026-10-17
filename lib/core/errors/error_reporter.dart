import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Central place for uncaught errors. Nothing is sent anywhere: in debug
/// builds errors are printed (with secrets redacted); release builds stay
/// silent until a crash-reporting service is deliberately added.
abstract final class ErrorReporter {
  static final _patterns = [
    // Authorization headers.
    RegExp(r'(Bearer\s+)[^\s",}]+', caseSensitive: false),
    // Music-User-Token header.
    RegExp(
      r'(Music-User-Token["]?\s*[:=]\s*["]?)[^\s",}]+',
      caseSensitive: false,
    ),
    // OAuth fields in JSON, query strings or form bodies.
    RegExp(
      r'''(["']?(?:access_token|refresh_token|code_verifier|code|token)["']?\s*[:=]\s*["']?)[^\s"'&,}]+''',
      caseSensitive: false,
    ),
  ];

  /// Replaces token-like values with `[redacted]`.
  static String redact(String input) {
    var out = input;
    for (final p in _patterns) {
      out = out.replaceAllMapped(p, (m) => '${m[1]}[redacted]');
    }
    return out;
  }

  static void report(Object error, StackTrace? stack) {
    if (!kDebugMode) return;
    debugPrint('MoodScape error: ${redact('$error')}');
    if (stack != null) debugPrint(redact('$stack'));
  }

  /// Hooks Flutter and platform error callbacks. Call once from `main()`.
  static void install() {
    FlutterError.onError = (details) {
      if (kDebugMode) {
        FlutterError.presentError(details);
      } else {
        report(details.exception, details.stack);
      }
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack);
      return true;
    };
    if (!kDebugMode) {
      // Replace the grey release-mode error box with something calmer.
      ErrorWidget.builder = (_) => const Material(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Something went wrong on this screen. Please go back and try '
              'again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
  }
}
