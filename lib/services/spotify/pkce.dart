import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// RFC 7636 helpers for Spotify's Authorization Code + PKCE flow.
abstract final class Pkce {
  static const _charset =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  /// 43–128 characters from the unreserved set, from a secure RNG.
  static String generateVerifier({int length = 64, Random? random}) {
    assert(length >= 43 && length <= 128);
    final rng = random ?? Random.secure();
    return String.fromCharCodes(
      List.generate(
        length,
        (_) => _charset.codeUnitAt(rng.nextInt(_charset.length)),
      ),
    );
  }

  /// S256: base64url(SHA-256(verifier)) without padding.
  static String challengeFor(String verifier) => base64Url
      .encode(sha256.convert(ascii.encode(verifier)).bytes)
      .replaceAll('=', '');

  /// Opaque value to detect forged callbacks.
  static String generateState({Random? random}) =>
      generateVerifier(length: 43, random: random);
}
