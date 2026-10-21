import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moodscape/app/app.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/camera/application/camera_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        availableCamerasProvider.overrideWithValue(() async => []),
      ],
      child: const MoodScapeApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Lists build lazily: scroll until [finder] exists and is on screen.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('welcome screen shows branding, privacy note and CTA', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('MoodScape'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.textContaining('Nothing is uploaded'), findsOneWidget);
  });

  testWidgets('privacy link opens the privacy screen', (tester) async {
    await pumpApp(tester);

    await tester.ensureVisible(find.text('How we handle your photos'));
    await tester.tap(find.text('How we handle your photos'));
    await tester.pumpAndSettle();

    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Uploads need consent'), findsOneWidget);
  });

  testWidgets('Get Started asks what the user is doing first', (tester) async {
    await pumpApp(tester);

    await tester.ensureVisible(find.text('Get Started'));
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('What are you doing?'), findsOneWidget);
    // Continue stays off until an activity is chosen.
    final continueButton = find.widgetWithText(FilledButton, 'Continue');
    await _scrollTo(tester, continueButton);
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

    await _scrollTo(tester, find.text('Exercise or gym'));
    await tester.tap(find.text('Exercise or gym'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, continueButton);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('Capture your surroundings'), findsOneWidget);
  });

  testWidgets('user can skip the photo and reach mood selection', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.ensureVisible(find.text('Get Started'));
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Driving'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue without a photo'));
    await tester.pumpAndSettle();

    expect(find.text('How are you feeling right now?'), findsOneWidget);
  });

  testWidgets('the ไทย button switches the app to Thai and back', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('ไทย'));
    await tester.pumpAndSettle();
    expect(find.text('เริ่มต้นใช้งาน'), findsOneWidget);
    expect(find.text('Get Started'), findsNothing);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('the chosen language is remembered', (tester) async {
    SharedPreferences.setMockInitialValues({'settings.language': 'thai'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MoodScapeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('เริ่มต้นใช้งาน'), findsOneWidget);
  });
}
