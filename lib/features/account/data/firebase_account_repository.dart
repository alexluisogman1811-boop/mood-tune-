import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/account.dart';
import 'account_repository.dart';

/// Firebase Authentication (email + password) and a Firestore `users`
/// collection, one document per user id. See firestore.rules for who may
/// read and write what.
class FirebaseAccountRepository implements AccountRepository {
  FirebaseAccountRepository({FirebaseAuth? auth, FirebaseFirestore? db})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  @override
  Stream<AuthUser?> authChanges() => _auth.userChanges().map(
    (u) => u == null
        ? null
        : AuthUser(
            uid: u.uid,
            email: u.email ?? '',
            emailVerified: u.emailVerified,
          ),
  );

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on FirebaseAuthException catch (e) {
      throw AccountFailure(_authMessage(e.code));
    } on FirebaseException catch (e) {
      throw AccountFailure(
        e.code == 'permission-denied'
            ? 'You are not allowed to do that.'
            : 'Could not reach the server. Try again.',
      );
    }
  }

  static String _authMessage(String code) => switch (code) {
    'invalid-email' => 'That email address is not valid.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'Wrong email or password.',
    'email-already-in-use' => 'An account with this email already exists.',
    'weak-password' => 'Use a password of at least 6 characters.',
    'too-many-requests' => 'Too many tries. Wait a moment and try again.',
    'requires-recent-login' =>
      'For your safety, sign in again before deleting your account.',
    'network-request-failed' => 'Could not reach the server. Try again.',
    _ => 'Something went wrong. Try again.',
  };

  @override
  Future<void> signIn(String email, String password) => _guard(
    () => _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  @override
  Future<void> signUp(String email, String password) => _guard(() async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    await _users.doc(user.uid).set({
      'email': user.email,
      'plan': Plan.free.name,
      'premiumUntil': null,
      'usageDate': null,
      'usageCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await user.sendEmailVerification();
  });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> resendVerification() =>
      _guard(() async => _auth.currentUser?.sendEmailVerification());

  @override
  Future<void> reloadUser() => _guard(() async => _auth.currentUser?.reload());

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _users.doc(user.uid).delete();
    await user.delete();
  });

  static Account? _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    if (d == null) return null;
    DateTime? time(Object? v) => v is Timestamp ? v.toDate() : null;
    return Account(
      uid: doc.id,
      email: d['email'] as String? ?? '',
      plan: Plan.values.firstWhere(
        (p) => p.name == d['plan'],
        orElse: () => Plan.free,
      ),
      premiumUntil: time(d['premiumUntil']),
      usageDate: d['usageDate'] as String?,
      usageCount: (d['usageCount'] as num?)?.toInt() ?? 0,
      createdAt: time(d['createdAt']),
      lastOpened: d['lastOpened'] as String?,
    );
  }

  @override
  Stream<Account?> watchAccount(String uid) =>
      _users.doc(uid).snapshots().map(_fromDoc);

  @override
  Future<void> recordPlaylist(Account account, DateTime now) => _guard(() {
    final today = Account.dayKey(now);
    return _users.doc(account.uid).update({
      'usageDate': today,
      'usageCount': account.usageDate == today ? account.usageCount + 1 : 1,
    });
  });

  @override
  Stream<List<Account>> watchAllAccounts() => _users
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) ?_fromDoc(d)]);

  @override
  Future<void> setPlan(Account account, Plan plan, DateTime now) => _guard(() {
    final until = account.untilAfterBuying(plan, now);
    final batch = _db.batch()
      ..update(_users.doc(account.uid), {
        'plan': plan.name,
        'premiumUntil': until == null ? null : Timestamp.fromDate(until),
      });
    // A record of each sale, for the admin website's income reports.
    if (plan.isPaid) {
      batch.set(_db.collection('payments').doc(), {
        'uid': account.uid,
        'email': account.email,
        'plan': plan.name,
        'usd': plan.usd,
        'thb': plan.thb,
        'at': FieldValue.serverTimestamp(),
      });
    }
    return batch.commit();
  });

  @override
  Future<void> markOpened(Account account, DateTime now) => _guard(() {
    final today = Account.dayKey(now);
    if (account.lastOpened == today) return Future.value();
    return _users.doc(account.uid).update({'lastOpened': today});
  });
}
