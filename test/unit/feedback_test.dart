import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodscape/app/app_info.dart';
import 'package:moodscape/core/configuration/app_config.dart';
import 'package:moodscape/core/configuration/config_provider.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/feedback/application/feedback_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppConfig _config(String feedbackUrl) => AppConfig(
  spotifyClientId: '',
  spotifyRedirectUri: '',
  analysisBackendUrl: '',
  appleMusicDeveloperTokenUrl: '',
  feedbackUrl: feedbackUrl,
);

Future<(ProviderContainer, SharedPreferences, void Function(Duration))> _setup({
  String feedbackUrl = 'https://example.com/feedback/',
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  var now = DateTime(2026, 10, 1, 9);
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => now),
      appConfigProvider.overrideWithValue(_config(feedbackUrl)),
    ],
  );
  addTearDown(c.dispose);
  void advance(Duration d) {
    now = now.add(d);
    c.invalidate(feedbackPromptProvider); // as if the app was reopened
  }

  return (c, prefs, advance);
}

void main() {
  test('app version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('version: $appVersion+'));
  });

  group('where the questions live', () {
    test('the configured site', () async {
      final (c, _, _) = await _setup();
      expect(
        c.read(feedbackSiteProvider),
        Uri.parse('https://example.com/feedback/'),
      );
    });

    test('nothing when the build has no site', () async {
      final (c, _, _) = await _setup(feedbackUrl: '');
      expect(c.read(feedbackSiteProvider), isNull);
    });

    test('nothing when the site is not https', () async {
      final (c, _, _) = await _setup(feedbackUrl: 'http://example.com/f/');
      expect(c.read(feedbackSiteProvider), isNull);
    });
  });

  group('when to ask', () {
    test('never before the app has been used', () async {
      final (c, _, advance) = await _setup();
      advance(const Duration(days: 3));
      expect(c.read(feedbackPromptProvider), isFalse);
    });

    test('only after a full day of use', () async {
      final (c, _, advance) = await _setup();
      await c.read(feedbackPromptProvider.notifier).recordUse();
      advance(const Duration(hours: 23));
      expect(c.read(feedbackPromptProvider), isFalse);
      advance(const Duration(hours: 1));
      expect(c.read(feedbackPromptProvider), isTrue);
    });

    test('the first use is the one that counts', () async {
      final (c, _, advance) = await _setup();
      final ctrl = c.read(feedbackPromptProvider.notifier);
      await ctrl.recordUse();
      advance(const Duration(hours: 20));
      await ctrl.recordUse();
      advance(const Duration(hours: 4));
      expect(c.read(feedbackPromptProvider), isTrue);
    });

    test('"Later" waits another day', () async {
      final (c, _, advance) = await _setup();
      await c.read(feedbackPromptProvider.notifier).recordUse();
      advance(const Duration(days: 1));
      await c.read(feedbackPromptProvider.notifier).snooze();
      expect(c.read(feedbackPromptProvider), isFalse);
      advance(const Duration(hours: 12));
      expect(c.read(feedbackPromptProvider), isFalse);
      advance(const Duration(hours: 13));
      expect(c.read(feedbackPromptProvider), isTrue);
    });

    // The answers are given on the web, so the app cannot know whether they
    // were finished. Being taken there has to be enough, or someone who
    // answered would be asked again every day.
    test('never again once the user has been taken to the site', () async {
      final (c, _, advance) = await _setup();
      await c.read(feedbackPromptProvider.notifier).recordUse();
      advance(const Duration(days: 1));
      await c.read(feedbackPromptProvider.notifier).markAsked();
      expect(c.read(feedbackPromptProvider), isFalse);
      advance(const Duration(days: 30));
      expect(c.read(feedbackPromptProvider), isFalse);
    });
  });
}
