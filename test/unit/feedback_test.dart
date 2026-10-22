import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodscape/app/app_info.dart';
import 'package:moodscape/core/errors/app_failure.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/feedback/application/feedback_controller.dart';
import 'package:moodscape/features/feedback/data/feedback_sender.dart';
import 'package:moodscape/features/feedback/domain/feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSender implements FeedbackSender {
  final sent = <Map<String, Object?>>[];
  bool fail = false;

  @override
  Future<void> send(Map<String, Object?> json) async {
    if (fail) throw const NetworkFailure();
    sent.add(json);
  }
}

Future<(ProviderContainer, SharedPreferences, void Function(Duration))> _setup({
  FeedbackSender? sender,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  var now = DateTime(2026, 10, 1, 9);
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => now),
      feedbackSenderProvider.overrideWithValue(sender),
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

    test('never again after answering', () async {
      final (c, _, advance) = await _setup(sender: FakeSender());
      await c.read(feedbackPromptProvider.notifier).recordUse();
      advance(const Duration(days: 1));
      await c
          .read(feedbackPromptProvider.notifier)
          .submit(const FeedbackAnswer(overall: 5), language: 'en');
      advance(const Duration(days: 30));
      expect(c.read(feedbackPromptProvider), isFalse);
    });
  });

  group('sending', () {
    test('sends an anonymous entry', () async {
      final sender = FakeSender();
      final (c, _, _) = await _setup(sender: sender);
      final outcome = await c
          .read(feedbackPromptProvider.notifier)
          .submit(
            const FeedbackAnswer(
              overall: 4,
              songMatch: 5,
              improvements: {Improvement.moreSongs},
              comment: 'More Thai songs please',
              recommend: Recommend.yes,
            ),
            language: 'th',
          );
      expect(outcome, FeedbackOutcome.sent);
      final e = sender.sent.single;
      expect(e['overall'], 4);
      expect(e['songMatch'], 5);
      expect(e['easeOfUse'], isNull);
      expect(e['improvements'], ['moreSongs']);
      expect(e['recommend'], 'yes');
      expect(e['language'], 'th');
      expect(e['appVersion'], appVersion);
      expect(e['installId'], matches(RegExp(r'^[0-9a-f]{16}$')));
      expect(e.keys, isNot(contains('name')));
    });

    test('offline answers are kept and sent next time', () async {
      final sender = FakeSender()..fail = true;
      final (c, prefs, _) = await _setup(sender: sender);
      final ctrl = c.read(feedbackPromptProvider.notifier);
      expect(
        await ctrl.submit(const FeedbackAnswer(overall: 2), language: 'en'),
        FeedbackOutcome.savedForLater,
      );
      expect(prefs.getStringList(FeedbackController.pendingKey), hasLength(1));

      sender.fail = false;
      expect(
        await ctrl.submit(const FeedbackAnswer(overall: 3), language: 'en'),
        FeedbackOutcome.sent,
      );
      expect([for (final e in sender.sent) e['overall']], [2, 3]);
      expect(prefs.getStringList(FeedbackController.pendingKey), isEmpty);
    });

    test('without a backend, answers stay on the device', () async {
      final (c, prefs, _) = await _setup();
      expect(
        await c
            .read(feedbackPromptProvider.notifier)
            .submit(const FeedbackAnswer(overall: 5), language: 'en'),
        FeedbackOutcome.savedForLater,
      );
      expect(prefs.getStringList(FeedbackController.pendingKey), hasLength(1));
    });
  });
}
