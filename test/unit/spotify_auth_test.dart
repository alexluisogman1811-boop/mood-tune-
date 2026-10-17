import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moodscape/core/errors/app_failure.dart';
import 'package:moodscape/services/spotify/pkce.dart';
import 'package:moodscape/services/spotify/spotify_auth_service.dart';
import 'package:moodscape/services/spotify/spotify_tokens.dart';

class _MockDio extends Mock implements Dio {}

const _redirect = 'moodscape://spotify-callback';
final _now = DateTime.utc(2026, 10, 17, 12);

Response<Object?> _ok(Object? data) =>
    Response(requestOptions: RequestOptions(), data: data, statusCode: 200);

DioException _status(int code) => DioException(
  requestOptions: RequestOptions(),
  type: DioExceptionType.badResponse,
  response: Response(requestOptions: RequestOptions(), statusCode: code),
);

void main() {
  setUpAll(() => registerFallbackValue(Uri()));

  group('PKCE', () {
    test('RFC 7636 appendix B test vector', () {
      expect(
        Pkce.challengeFor('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('verifier uses only unreserved characters at a valid length', () {
      final v = Pkce.generateVerifier();
      expect(v.length, inInclusiveRange(43, 128));
      expect(RegExp(r'^[A-Za-z0-9\-._~]+$').hasMatch(v), isTrue);
      expect(Pkce.generateVerifier(), isNot(v));
    });
  });

  group('SpotifyAuthService', () {
    late _MockDio dio;
    late SpotifyTokenStore store;
    late List<Uri> launched;
    late FutureOr<String> Function(Uri url) onLaunch;

    SpotifyAuthService service() => SpotifyAuthService(
      clientId: 'client-123',
      redirectUri: _redirect,
      dio: dio,
      store: store,
      clock: () => _now,
      launcher: (url, scheme) async {
        expect(scheme, 'moodscape');
        launched.add(url);
        return onLaunch(url);
      },
    );

    void stubToken(Object? Function(Map form) reply) {
      when(
        () => dio.postUri<Object?>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((inv) async {
        final r = reply(inv.namedArguments[#data] as Map);
        if (r is DioException) throw r;
        return _ok(r);
      });
    }

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      store = const SpotifyTokenStore(FlutterSecureStorage());
      dio = _MockDio();
      launched = [];
    });

    test('authorize URL has PKCE, state, scopes and exact redirect', () {
      final url = service().buildAuthorizeUrl(challenge: 'c', state: 's');
      expect(url.host, 'accounts.spotify.com');
      expect(url.queryParameters, {
        'client_id': 'client-123',
        'response_type': 'code',
        'redirect_uri': _redirect,
        'code_challenge_method': 'S256',
        'code_challenge': 'c',
        'state': 's',
        'scope': 'playlist-modify-private playlist-modify-public',
      });
    });

    test('connect exchanges the code with the matching verifier', () async {
      onLaunch = (url) =>
          '$_redirect?code=abc&state=${url.queryParameters['state']}';
      Map? sentForm;
      stubToken((form) {
        sentForm = form;
        return {
          'access_token': 'AT',
          'refresh_token': 'RT',
          'expires_in': 3600,
          'scope': 'playlist-modify-private',
        };
      });

      await service().connect();

      expect(sentForm!['grant_type'], 'authorization_code');
      expect(sentForm!['code'], 'abc');
      expect(sentForm!['redirect_uri'], _redirect);
      expect(sentForm!.containsKey('client_secret'), isFalse);
      expect(
        Pkce.challengeFor(sentForm!['code_verifier'] as String),
        launched.single.queryParameters['code_challenge'],
      );
      final saved = await store.read();
      expect(saved!.accessToken, 'AT');
      expect(saved.expiresAt, _now.add(const Duration(hours: 1)));
    });

    test('rejects a callback with the wrong state', () async {
      onLaunch = (_) => '$_redirect?code=abc&state=forged';
      await expectLater(service().connect(), throwsA(isA<AuthFailure>()));
      expect(await store.read(), isNull);
    });

    test('user denial and closing the browser are cancellations', () async {
      onLaunch = (url) =>
          '$_redirect?error=access_denied&state=${url.queryParameters['state']}';
      await expectLater(
        service().connect(),
        throwsA(isA<AuthCancelledFailure>()),
      );

      onLaunch = (_) => throw PlatformException(code: 'CANCELED');
      await expectLater(
        service().connect(),
        throwsA(isA<AuthCancelledFailure>()),
      );
    });

    test('valid token is returned without a network call', () async {
      await store.write(
        SpotifyTokens(
          accessToken: 'AT',
          refreshToken: 'RT',
          expiresAt: _now.add(const Duration(minutes: 30)),
          scopes: const {},
        ),
      );
      expect(await service().validAccessToken(), 'AT');
      verifyNever(
        () => dio.postUri<Object?>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      );
    });

    test('expired token refreshes once for concurrent callers and keeps '
        'the refresh token when none is returned', () async {
      await store.write(
        SpotifyTokens(
          accessToken: 'old',
          refreshToken: 'RT',
          expiresAt: _now.subtract(const Duration(seconds: 1)),
          scopes: const {},
        ),
      );
      var calls = 0;
      stubToken((form) {
        calls++;
        expect(form['grant_type'], 'refresh_token');
        expect(form['refresh_token'], 'RT');
        return {'access_token': 'new', 'expires_in': 3600};
      });

      final auth = service();
      final tokens = await Future.wait([
        auth.validAccessToken(),
        auth.validAccessToken(),
        auth.validAccessToken(),
      ]);

      expect(tokens, ['new', 'new', 'new']);
      expect(calls, 1);
      expect((await store.read())!.refreshToken, 'RT');
    });

    test(
      'revoked refresh token clears storage and asks to reconnect',
      () async {
        await store.write(
          SpotifyTokens(
            accessToken: 'old',
            refreshToken: 'revoked',
            expiresAt: _now.subtract(const Duration(minutes: 5)),
            scopes: const {},
          ),
        );
        stubToken((_) => _status(400));

        await expectLater(
          service().validAccessToken(),
          throwsA(isA<AuthFailure>()),
        );
        expect(await store.read(), isNull);
      },
    );

    test('offline refresh keeps the tokens', () async {
      await store.write(
        SpotifyTokens(
          accessToken: 'old',
          refreshToken: 'RT',
          expiresAt: _now.subtract(const Duration(minutes: 5)),
          scopes: const {},
        ),
      );
      stubToken(
        (_) => DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        service().validAccessToken(),
        throwsA(isA<NetworkFailure>()),
      );
      expect(await store.read(), isNotNull);
    });

    test('tokens never appear in toString', () {
      final t = SpotifyTokens(
        accessToken: 'secret-access',
        refreshToken: 'secret-refresh',
        expiresAt: _now,
        scopes: const {},
      );
      expect(t.toString(), isNot(contains('secret')));
    });
  });
}
