import '../domain/account.dart';

/// The signed-in person, as far as sign-in is concerned.
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.emailVerified,
  });
  final String uid;
  final String email;
  final bool emailVerified;
}

/// Why a sign-in step failed, in words the UI can show.
class AccountFailure implements Exception {
  const AccountFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Sign-in plus the users database. Firebase in the app, a fake in tests.
abstract interface class AccountRepository {
  Stream<AuthUser?> authChanges();
  Future<void> signIn(String email, String password);

  /// Creates the login and the user's Free record, and sends a
  /// verification email.
  Future<void> signUp(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> resendVerification();

  /// Re-reads the signed-in user (e.g. after they verified their email).
  Future<void> reloadUser();
  Future<void> signOut();

  /// Deletes the user's record and login. May ask to sign in again.
  Future<void> deleteAccount();

  Stream<Account?> watchAccount(String uid);

  /// Counts one playlist for [account] today.
  Future<void> recordPlaylist(Account account, DateTime now);

  // ---- Admin only (the database rules enforce this) -----------------------

  Stream<List<Account>> watchAllAccounts();

  /// Sets [plan] for [account]; Monthly and Yearly extend from today (or
  /// from the current end date when still active).
  Future<void> setPlan(Account account, Plan plan, DateTime now);
}
