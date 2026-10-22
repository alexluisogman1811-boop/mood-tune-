import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_info.dart';
import '../../../core/configuration/config_provider.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/storage/storage_providers.dart';
import '../data/feedback_sender.dart';
import '../domain/feedback.dart';

/// Injectable clock so the "after one day" rule can be tested.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Null when this build has no feedback backend configured.
final feedbackSenderProvider = Provider<FeedbackSender?>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.hasFeedbackBackend) return null;
  return HttpFeedbackSender(
    ref.watch(dioProvider),
    Uri.parse(config.feedbackUrl),
  );
});

enum FeedbackOutcome {
  /// Delivered.
  sent,

  /// Kept on this device and retried next time (offline, or no backend).
  savedForLater,
}

/// True when the app should invite the user to give feedback: a day has
/// passed since they first got a playlist, they haven't answered, and they
/// didn't just tap "Later".
final feedbackPromptProvider = NotifierProvider<FeedbackController, bool>(
  FeedbackController.new,
);

class FeedbackController extends Notifier<bool> {
  static const firstUseKey = 'feedback.first_use';
  static const doneKey = 'feedback.done';
  static const snoozeKey = 'feedback.snooze_until';
  static const installIdKey = 'feedback.install_id';
  static const pendingKey = 'feedback.pending';
  static const askAfter = Duration(days: 1);

  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final now = ref.read(clockProvider)();
    final firstUse = DateTime.tryParse(prefs.getString(firstUseKey) ?? '');
    final snooze = DateTime.tryParse(prefs.getString(snoozeKey) ?? '');
    return firstUse != null &&
        now.difference(firstUse) >= askAfter &&
        !(prefs.getBool(doneKey) ?? false) &&
        (snooze == null || now.isAfter(snooze));
  }

  /// Called when the user gets a playlist; only the first time counts.
  Future<void> recordUse() async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.containsKey(firstUseKey)) return;
    await prefs.setString(
      firstUseKey,
      ref.read(clockProvider)().toIso8601String(),
    );
  }

  /// "Later": ask again in a day.
  Future<void> snooze() async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(
          snoozeKey,
          ref.read(clockProvider)().add(askAfter).toIso8601String(),
        );
    state = false;
  }

  Future<FeedbackOutcome> submit(
    FeedbackAnswer answer, {
    required String language,
  }) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final entry = answer.toJson(
      installId: _installId(),
      language: language,
      platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
      appVersion: appVersion,
    );
    await prefs.setBool(doneKey, true);
    state = false;

    final pending = [...?prefs.getStringList(pendingKey), jsonEncode(entry)];
    final sender = ref.read(feedbackSenderProvider);
    if (sender == null) {
      await prefs.setStringList(pendingKey, pending);
      return FeedbackOutcome.savedForLater;
    }
    // Send anything saved earlier too, oldest first.
    final left = <String>[];
    for (final p in pending) {
      try {
        await sender.send(jsonDecode(p) as Map<String, Object?>);
      } on AppFailure {
        left.add(p);
      }
    }
    await prefs.setStringList(pendingKey, left);
    return left.contains(pending.last)
        ? FeedbackOutcome.savedForLater
        : FeedbackOutcome.sent;
  }

  /// A random id per install so repeat answers can be told apart, without
  /// knowing who anyone is.
  String _installId() {
    final prefs = ref.read(sharedPreferencesProvider);
    final existing = prefs.getString(installIdKey);
    if (existing != null) return existing;
    final rnd = Random.secure();
    final id = [
      for (var i = 0; i < 8; i++)
        rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    prefs.setString(installIdKey, id);
    return id;
  }
}
