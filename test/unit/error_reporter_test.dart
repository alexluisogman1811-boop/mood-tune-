import 'package:flutter_test/flutter_test.dart';
import 'package:moodscape/core/errors/error_reporter.dart';

void main() {
  test('redacts bearer tokens and user tokens', () {
    final out = ErrorReporter.redact(
      'headers: {Authorization: Bearer abc.def.ghi, '
      'Music-User-Token: secretUserToken}',
    );
    expect(out, isNot(contains('abc.def.ghi')));
    expect(out, isNot(contains('secretUserToken')));
    expect(out, contains('Bearer [redacted]'));
  });

  test('redacts OAuth fields in JSON, query strings and form bodies', () {
    for (final input in [
      '{"access_token": "AT123", "refresh_token": "RT456"}',
      'moodscape://spotify-callback?code=AUTHCODE&state=s',
      'grant_type=authorization_code&code_verifier=VERIFIER&client_id=c',
    ]) {
      final out = ErrorReporter.redact(input);
      for (final secret in ['AT123', 'RT456', 'AUTHCODE', 'VERIFIER']) {
        expect(out, isNot(contains(secret)), reason: input);
      }
    }
  });

  test('leaves ordinary messages readable', () {
    const msg = 'NetworkFailure: Could not reach Spotify.';
    expect(ErrorReporter.redact(msg), msg);
  });
}
