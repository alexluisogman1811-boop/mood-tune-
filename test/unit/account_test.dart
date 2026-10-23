import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodscape/core/configuration/app_config.dart';
import 'package:moodscape/core/configuration/config_provider.dart';
import 'package:moodscape/features/account/application/account_providers.dart';
import 'package:moodscape/features/account/domain/account.dart';
import 'package:moodscape/features/feedback/application/feedback_controller.dart';

import '../fakes/fake_account_repository.dart';

final _now = DateTime(2026, 10, 22, 9);

void main() {
  group('Account', () {
    test('Free is never Premium; Lifetime always is', () {
      expect(const Account(uid: 'a', email: 'a').isPremium(_now), isFalse);
      expect(
        const Account(
          uid: 'a',
          email: 'a',
          plan: Plan.lifetime,
        ).isPremium(_now),
        isTrue,
      );
    });

    test('Monthly and Yearly last until their end date', () {
      final a = Account(
        uid: 'a',
        email: 'a',
        plan: Plan.monthly,
        premiumUntil: _now.add(const Duration(days: 1)),
      );
      expect(a.isPremium(_now), isTrue);
      expect(a.isPremium(_now.add(const Duration(days: 2))), isFalse);
    });

    test('free playlists reset each day', () {
      final a = Account(
        uid: 'a',
        email: 'a',
        usageDate: Account.dayKey(_now),
        usageCount: 2,
      );
      expect(a.playlistsLeft(_now), 1);
      expect(a.playlistsLeft(_now.add(const Duration(days: 1))), 3);
    });

    test('Premium has no playlist limit', () {
      const a = Account(uid: 'a', email: 'a', plan: Plan.lifetime);
      expect(a.playlistsLeft(_now), isNull);
    });

    test('buying again keeps the time already paid for', () {
      final a = Account(
        uid: 'a',
        email: 'a',
        plan: Plan.monthly,
        premiumUntil: _now.add(const Duration(days: 10)),
      );
      expect(
        a.untilAfterBuying(Plan.monthly, _now),
        _now.add(const Duration(days: 40)),
      );
      expect(
        const Account(uid: 'b', email: 'b').untilAfterBuying(Plan.yearly, _now),
        _now.add(const Duration(days: 365)),
      );
      expect(a.untilAfterBuying(Plan.lifetime, _now), isNull);
    });

    test('plan prices match what is sold', () {
      expect(Plan.monthly.price, r'$2.99');
      expect(Plan.yearly.price, r'$24.99');
      expect(Plan.lifetime.price, r'$39.99');
      expect(Plan.free.isPaid, isFalse);
    });
  });

  group('Entitlements', () {
    test('Free caps playlists at 10 songs and has no photo', () {
      const e = Entitlements(
        premium: false,
        playlistsLeft: 3,
        accountsEnabled: true,
      );
      expect(e.maxPlaylistLength(30), 10);
      expect(e.maxPlaylistLength(10), 10);
      expect(e.canUsePhoto, isFalse);
    });

    test('Premium keeps the chosen length and the photo', () {
      const e = Entitlements(
        premium: true,
        playlistsLeft: null,
        accountsEnabled: true,
      );
      expect(e.maxPlaylistLength(30), 30);
      expect(e.canUsePhoto, isTrue);
    });
  });

  group('playlist usage', () {
    Future<(ProviderContainer, FakeAccountRepository)> signedIn(
      Plan plan,
    ) async {
      final repo = FakeAccountRepository();
      repo.addUser(
        'user@example.com',
        plan: plan,
        until: _now.add(const Duration(days: 5)),
      );
      final c = ProviderContainer(
        overrides: [
          accountsEnabledProvider.overrideWithValue(true),
          accountRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => _now),
        ],
      );
      addTearDown(c.dispose);
      c.listen(entitlementsProvider, (_, _) {});
      await repo.signIn('user@example.com', 'secret1');
      await pumpEventQueue();
      return (c, repo);
    }

    test('Free users get 3 playlists a day, then must upgrade', () async {
      final (c, repo) = await signedIn(Plan.free);
      final use = c.read(playlistUsageProvider);
      for (var i = 0; i < 3; i++) {
        expect(await use(), isTrue, reason: 'playlist ${i + 1}');
        await pumpEventQueue();
      }
      expect(await use(), isFalse);
      expect(repo.accountFor('user@example.com')!.usageCount, 3);
    });

    test('works even before anything has loaded the account', () async {
      // Regression: reading the plan before the account record arrived
      // looked like "no playlists left" and sent new users to Upgrade.
      final repo = FakeAccountRepository()..addUser('fresh@example.com');
      await repo.signIn('fresh@example.com', 'secret1');
      final c = ProviderContainer(
        overrides: [
          accountsEnabledProvider.overrideWithValue(true),
          accountRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => _now),
        ],
      );
      addTearDown(c.dispose);
      // As on the analysis screen, which watches the account.
      c.listen(accountProvider, (_, _) {});
      expect(await c.read(playlistUsageProvider)(), isTrue);
      expect(repo.accountFor('fresh@example.com')!.usageCount, 1);
    });

    test('opening the app saves today as the last-open day, once', () async {
      final (c, repo) = await signedIn(Plan.free);
      c.listen(openTrackerProvider, (_, _) {});
      await pumpEventQueue();
      expect(
        repo.accountFor('user@example.com')!.lastOpened,
        Account.dayKey(_now),
      );
    });

    test('giving a paid plan records a payment; Free does not', () async {
      final repo = FakeAccountRepository()
        ..addUser('buyer@example.com')
        ..addUser('admin@example.com');
      await repo.signIn('admin@example.com', 'secret1');
      await repo.setPlan(
        repo.accountFor('buyer@example.com')!,
        Plan.yearly,
        _now,
      );
      await repo.setPlan(
        repo.accountFor('buyer@example.com')!,
        Plan.free,
        _now,
      );
      expect(repo.payments, [('buyer@example.com', Plan.yearly)]);
      expect(Plan.yearly.thb, 899);
      expect(Plan.lifetime.usd, 39.99);
    });

    test('Premium users are never limited', () async {
      final (c, _) = await signedIn(Plan.monthly);
      final use = c.read(playlistUsageProvider);
      for (var i = 0; i < 10; i++) {
        expect(await use(), isTrue);
      }
    });

    test('with accounts off (development), everything is unlocked', () {
      final c = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              spotifyClientId: '',
              spotifyRedirectUri: '',
              analysisBackendUrl: '',
              appleMusicDeveloperTokenUrl: '',
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      final e = c.read(entitlementsProvider);
      expect(e.premium, isTrue);
      expect(e.playlistsLeft, isNull);
      expect(e.accountsEnabled, isFalse);
    });
  });

  test('admin list comes from ADMIN_EMAILS, case-insensitive', () {
    const config = AppConfig(
      spotifyClientId: '',
      spotifyRedirectUri: '',
      analysisBackendUrl: '',
      appleMusicDeveloperTokenUrl: '',
      adminEmails: 'Owner@Example.com, second@example.com',
    );
    expect(config.adminEmailSet, {'owner@example.com', 'second@example.com'});
  });
}
