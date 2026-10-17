/// Typed failures surfaced to the UI. Messages are user-facing and must never
/// contain tokens, keys or raw server payloads.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = 'Network unavailable. Try again.']);
}

class PermissionFailure extends AppFailure {
  const PermissionFailure(super.message);
}

class NotConfiguredFailure extends AppFailure {
  const NotConfiguredFailure(super.message);
}

class InvalidResponseFailure extends AppFailure {
  const InvalidResponseFailure([
    super.message = 'Received an unexpected response.',
  ]);
}

class AuthFailure extends AppFailure {
  const AuthFailure([super.message = 'Please reconnect your account.']);
}

/// The user backed out of a sign-in flow. Not an error to show.
class AuthCancelledFailure extends AppFailure {
  const AuthCancelledFailure([super.message = 'Sign-in was cancelled.']);
}

class UnsupportedPlatformFailure extends AppFailure {
  const UnsupportedPlatformFailure(super.message);
}
