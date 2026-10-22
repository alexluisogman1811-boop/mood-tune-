import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/configuration/app_config.dart';
import 'core/errors/error_reporter.dart';
import 'core/storage/storage_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorReporter.install();
  final prefs = await SharedPreferences.getInstance();

  final config = AppConfig.fromEnvironment();
  if (config.hasAccounts) {
    final android =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        config.firebaseAndroidAppId.isNotEmpty;
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: config.firebaseApiKey,
        appId: android ? config.firebaseAndroidAppId : config.firebaseAppId,
        messagingSenderId: config.firebaseMessagingSenderId,
        projectId: config.firebaseProjectId,
        authDomain: config.firebaseAuthDomain.isEmpty
            ? null
            : config.firebaseAuthDomain,
      ),
    );
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MoodScapeApp(),
    ),
  );
}
