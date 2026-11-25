import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/configuration/config_provider.dart';
import '../../../core/storage/storage_providers.dart';

/// Injectable clock so the "after one day" rule can be tested.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Where the feedback questions live, or null when this build has no
/// feedback site configured. Answers are collected on the web rather than
/// in the app, so there is nothing here that sends or stores them.
final feedbackSiteProvider = Provider<Uri?>((ref) {
  final config = ref.watch(appConfigProvider);
  return config.hasFeedbackSite ? Uri.parse(config.feedbackUrl) : null;
});

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

  /// Stop asking. Called once the user has been taken to the feedback site:
  /// the answers are submitted there, so the app never learns whether they
  /// finished, and asking again would nag someone who already answered.
  Future<void> markAsked() async {
    await ref.read(sharedPreferencesProvider).setBool(doneKey, true);
    state = false;
  }
}
