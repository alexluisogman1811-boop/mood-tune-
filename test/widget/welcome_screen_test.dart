import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('Get Started navigates to the capture step', (tester) async {
    await pumpApp(tester);

    await tester.ensureVisible(find.text('Get Started'));
    await tester.tap(find.text('Get Started'));
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
    await tester.tap(find.text('Continue without a photo'));
    await tester.pumpAndSettle();

    expect(find.text('How are you feeling right now?'), findsOneWidget);
  });
}
