import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/configuration/config_provider.dart';
import '../../feedback/application/feedback_controller.dart';
import '../data/account_repository.dart';
import '../data/firebase_account_repository.dart';
import '../domain/account.dart';

/// True when this build has a Firebase project: people must sign in and
/// plans apply. False in development builds, where everything is unlocked.
final accountsEnabledProvider = Provider<bool>(
  (ref) => ref.watch(appConfigProvider).hasAccounts,
);

/// Null when accounts are switched off.
final accountRepositoryProvider = Provider<AccountRepository?>(
  (ref) =>
      ref.watch(accountsEnabledProvider) ? FirebaseAccountRepository() : null,
);

final authUserProvider = StreamProvider<AuthUser?>((ref) {
  final repo = ref.watch(accountRepositoryProvider);
  return repo == null ? Stream.value(null) : repo.authChanges();
});

/// The signed-in user's record; null while signed out or loading.
final accountProvider = StreamProvider<Account?>((ref) {
  final repo = ref.watch(accountRepositoryProvider);
  final user = ref.watch(authUserProvider).value;
  if (repo == null || user == null) return Stream.value(null);
  return repo.watchAccount(user.uid);
});

/// The admin page is shown only to these verified emails. The database
/// rules check the same thing, so hiding it is a convenience, not security.
final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(authUserProvider).value;
  if (user == null || !user.emailVerified) return false;
  return ref
      .watch(appConfigProvider)
      .adminEmailSet
      .contains(user.email.toLowerCase());
});

final entitlementsProvider = Provider<Entitlements>((ref) {
  if (!ref.watch(accountsEnabledProvider)) {
    return const Entitlements.unlimited();
  }
  final account = ref.watch(accountProvider).value;
  final now = ref.watch(clockProvider)();
  if (account == null) {
    return const Entitlements(
      premium: false,
      playlistsLeft: 0,
      accountsEnabled: true,
    );
  }
  return Entitlements(
    premium: account.isPremium(now),
    playlistsLeft: account.playlistsLeft(now),
    accountsEnabled: true,
  );
});

/// Saves the day the app was opened (date only) for the admin's
/// active-user counts. Watched once at the app's root.
final openTrackerProvider = Provider<void>((ref) {
  ref.listen(accountProvider, (_, next) {
    final account = next.value;
    final repo = ref.read(accountRepositoryProvider);
    if (account == null || repo == null) return;
    final now = ref.read(clockProvider)();
    if (account.lastOpened == Account.dayKey(now)) return;
    // Best effort: a failed write only makes the statistics a little low.
    repo.markOpened(account, now).catchError((Object _) {});
  }, fireImmediately: true);
});

/// Uses one of today's playlists. Returns false when a Free user has none
/// left, so the caller can show the upgrade screen instead.
///
/// Waits for the sign-in and the account record to load first: reading
/// them before they arrive would look like "no playlists left".
final playlistUsageProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    if (!ref.read(accountsEnabledProvider)) return true;
    final repo = ref.read(accountRepositoryProvider);
    final user = await ref.read(authUserProvider.future);
    if (repo == null || user == null) return false;
    final account = await ref.read(accountProvider.future);
    if (account == null) return false;
    final now = ref.read(clockProvider)();
    if (account.isPremium(now)) return true;
    if ((account.playlistsLeft(now) ?? 0) <= 0) return false;
    await repo.recordPlaylist(account, now);
    return true;
  };
});
