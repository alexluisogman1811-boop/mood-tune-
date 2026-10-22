import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    // Test builds only: talk to the local Firebase emulators, not the real
    // project (see tool/firestore_rules_test).
    if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
      await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    }
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MoodScapeApp(),
    ),
  );
}
