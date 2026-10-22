import 'dart:async';

import 'package:moodscape/features/account/data/account_repository.dart';
import 'package:moodscape/features/account/domain/account.dart';

/// In-memory accounts that follow the same rules as firestore.rules for
/// what a normal user may change.
class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({this.adminEmail = 'admin@example.com'});

  final String adminEmail;
  final _passwords = <String, String>{};
  final _accounts = <String, Account>{};
  final _verified = <String>{};
  AuthUser? _current;
  final _auth = StreamController<AuthUser?>.broadcast();
  final _changes = StreamController<void>.broadcast();
  var _next = 0;

  Account? accountFor(String email) =>
      _accounts.values.where((a) => a.email == email).firstOrNull;

  /// Test helper: an existing, verified user.
  Account addUser(String email, {Plan plan = Plan.free, DateTime? until}) {
    final uid = 'u${_next++}';
    _passwords[email] = 'secret1';
    _verified.add(uid);
    final a = Account(uid: uid, email: email, plan: plan, premiumUntil: until);
    _accounts[uid] = a;
    return a;
  }

  void _set(Account a) {
    _accounts[a.uid] = a;
    _changes.add(null);
  }

  void _emit() => _auth.add(_current);

  @override
  Stream<AuthUser?> authChanges() async* {
    yield _current;
    yield* _auth.stream;
  }

  @override
  Future<void> signIn(String email, String password) async {
    if (_passwords[email] != password) {
      throw const AccountFailure('Wrong email or password.');
    }
    final a = accountFor(email)!;
    _current = AuthUser(
      uid: a.uid,
      email: email,
      emailVerified: _verified.contains(a.uid),
    );
    _emit();
  }

  @override
  Future<void> signUp(String email, String password) async {
    if (_passwords.containsKey(email)) {
      throw const AccountFailure('An account with this email already exists.');
    }
    final uid = 'u${_next++}';
    _passwords[email] = password;
    _set(Account(uid: uid, email: email));
    _current = AuthUser(uid: uid, email: email, emailVerified: false);
    _emit();
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> resendVerification() async {}

  @override
  Future<void> reloadUser() async {}

  @override
  Future<void> signOut() async {
    _current = null;
    _emit();
  }

  @override
  Future<void> deleteAccount() async {
    final user = _current;
    if (user == null) return;
    _accounts.remove(user.uid);
    _passwords.remove(user.email);
    await signOut();
  }

  @override
  Stream<Account?> watchAccount(String uid) async* {
    yield _accounts[uid];
    yield* _changes.stream.map((_) => _accounts[uid]);
  }

  @override
  Future<void> recordPlaylist(Account account, DateTime now) async {
    final today = Account.dayKey(now);
    final current = _accounts[account.uid]!;
    _set(
      Account(
        uid: current.uid,
        email: current.email,
        plan: current.plan,
        premiumUntil: current.premiumUntil,
        usageDate: today,
        usageCount: current.usageDate == today ? current.usageCount + 1 : 1,
      ),
    );
  }

  bool get _isAdmin =>
      _current != null &&
      _current!.emailVerified &&
      _current!.email == adminEmail;

  @override
  Stream<List<Account>> watchAllAccounts() async* {
    if (!_isAdmin) {
      throw const AccountFailure('You are not allowed to do that.');
    }
    yield _accounts.values.toList();
    yield* _changes.stream.map((_) => _accounts.values.toList());
  }

  @override
  Future<void> setPlan(Account account, Plan plan, DateTime now) async {
    if (!_isAdmin) {
      throw const AccountFailure('You are not allowed to do that.');
    }
    final current = _accounts[account.uid]!;
    _set(
      Account(
        uid: current.uid,
        email: current.email,
        plan: plan,
        premiumUntil: current.untilAfterBuying(plan, now),
        usageDate: current.usageDate,
        usageCount: current.usageCount,
      ),
    );
  }
}
