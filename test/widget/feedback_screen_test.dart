import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/feedback/application/feedback_controller.dart';
import 'package:moodscape/features/feedback/presentation/feedback_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../unit/feedback_test.dart' show FakeSender;

Future<FakeSender> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final sender = FakeSender();
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(path: '/feedback', builder: (_, _) => const FeedbackScreen()),
    ],
  );
  addTearDown(router.dispose);
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        feedbackSenderProvider.overrideWithValue(sender),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.push('/feedback');
  await tester.pumpAndSettle();
  return sender;
}

void main() {
  testWidgets('send stays off until an overall rating is given', (
    tester,
  ) async {
    await _pump(tester);
    final send = find.widgetWithText(FilledButton, 'Send feedback');
    await tester.scrollUntilVisible(
      send,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
  });

  testWidgets('a rating, a request and a comment are sent', (tester) async {
    final sender = await _pump(tester);

    await tester.tap(find.byTooltip('4 of 5 stars').first);
    await tester.tap(find.text('More songs'));
    await tester.pumpAndSettle();
    final comment = find.byType(TextField);
    await tester.scrollUntilVisible(
      comment,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(comment, 'Love the gym mode');
    final send = find.widgetWithText(FilledButton, 'Send feedback');
    await tester.ensureVisible(send);
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pumpAndSettle();

    final e = sender.sent.single;
    expect(e['overall'], 4);
    expect(e['improvements'], ['moreSongs']);
    expect(e['comment'], 'Love the gym mode');
    expect(find.text('Thank you! Your feedback was sent.'), findsOneWidget);
    expect(find.text('home'), findsOneWidget); // screen closed
  });
}
