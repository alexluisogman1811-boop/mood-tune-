import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moodscape/app/app.dart';
import 'package:moodscape/app/router.dart';
import 'package:moodscape/core/configuration/app_config.dart';
import 'package:moodscape/core/configuration/config_provider.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/account/application/account_providers.dart';
import 'package:moodscape/features/account/domain/account.dart';
import 'package:moodscape/features/camera/application/camera_providers.dart';
import 'package:moodscape/features/feedback/application/feedback_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_account_repository.dart';

final _now = DateTime(2026, 10, 22, 9);

Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  FakeAccountRepository repo,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appConfigProvider.overrideWithValue(
        const AppConfig(
          spotifyClientId: '',
          spotifyRedirectUri: '',
          analysisBackendUrl: '',
          appleMusicDeveloperTokenUrl: '',
          adminEmails: 'admin@example.com',
          paymentInfo: 'PromptPay 000-000-0000',
        ),
      ),
      accountsEnabledProvider.overrideWithValue(true),
      accountRepositoryProvider.overrideWithValue(repo),
      clockProvider.overrideWithValue(() => _now),
      availableCamerasProvider.overrideWithValue(() async => []),
    ],
  );
  addTearDown(c.dispose);
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: c, child: const MoodScapeApp()),
  );
  await tester.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('signed-out people see the login page first', (tester) async {
    await _pumpApp(tester, FakeAccountRepository());
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Get Started'), findsNothing);
  });

  testWidgets('wrong password shows a clear message', (tester) async {
    final repo = FakeAccountRepository()..addUser('a@example.com');
    await _pumpApp(tester, repo);
    await tester.enterText(find.byType(TextFormField).at(0), 'a@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'nope123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Wrong email or password.'), findsOneWidget);
  });

  testWidgets('signing in opens the app', (tester) async {
    final repo = FakeAccountRepository()..addUser('a@example.com');
    await _pumpApp(tester, repo);
    await tester.enterText(find.byType(TextFormField).at(0), 'a@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret1');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('creating an account starts on the Free plan', (tester) async {
    final repo = FakeAccountRepository();
    await _pumpApp(tester, repo);
    await tester.tap(find.text('Create a new account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'new@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret1');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Get Started'), findsOneWidget);
    expect(repo.accountFor('new@example.com')!.plan, Plan.free);
  });

  testWidgets('Free users see the Premium lock instead of the camera', (
    tester,
  ) async {
    final repo = FakeAccountRepository()..addUser('a@example.com');
    final c = await _pumpApp(tester, repo);
    await repo.signIn('a@example.com', 'secret1');
    await tester.pumpAndSettle();
    c.read(routerProvider).push(AppRoutes.capture);
    await tester.pumpAndSettle();
    expect(find.text('Photo analysis is a Premium feature'), findsOneWidget);
    expect(find.text('Continue without a photo'), findsOneWidget);
  });

  testWidgets('the upgrade page shows all three prices and how to pay', (
    tester,
  ) async {
    final repo = FakeAccountRepository()..addUser('a@example.com');
    final c = await _pumpApp(tester, repo);
    await repo.signIn('a@example.com', 'secret1');
    await tester.pumpAndSettle();
    c.read(routerProvider).push(AppRoutes.upgrade);
    await tester.pumpAndSettle();
    for (final price in [r'$2.99', r'$24.99', r'$39.99']) {
      expect(find.text(price), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.text('PromptPay 000-000-0000'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('a@example.com'), findsOneWidget);
  });

  testWidgets('the admin can give a user the Yearly plan', (tester) async {
    final repo = FakeAccountRepository()
      ..addUser('admin@example.com')
      ..addUser('buyer@example.com');
    final c = await _pumpApp(tester, repo);
    await repo.signIn('admin@example.com', 'secret1');
    await tester.pumpAndSettle();
    expect(c.read(isAdminProvider), isTrue);
    c.read(routerProvider).push(AppRoutes.admin);
    await tester.pumpAndSettle();

    await tester.tap(find.text('buyer@example.com'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Give Yearly'));
    await tester.pumpAndSettle();

    final buyer = repo.accountFor('buyer@example.com')!;
    expect(buyer.plan, Plan.yearly);
    expect(buyer.premiumUntil, _now.add(const Duration(days: 365)));
    expect(buyer.isPremium(_now), isTrue);
  });

  testWidgets('normal users are not admins', (tester) async {
    final repo = FakeAccountRepository()..addUser('a@example.com');
    final c = await _pumpApp(tester, repo);
    await repo.signIn('a@example.com', 'secret1');
    await tester.pumpAndSettle();
    expect(c.read(isAdminProvider), isFalse);
    // Even if they open the page, the database refuses.
    c.read(routerProvider).push(AppRoutes.admin);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Only the admin account can see this page'),
      findsOneWidget,
    );
  });
}
