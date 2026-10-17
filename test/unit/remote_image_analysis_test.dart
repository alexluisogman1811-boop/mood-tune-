import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moodscape/core/errors/app_failure.dart';
import 'package:moodscape/services/image_analysis/remote_image_analysis_service.dart';
import 'package:moodscape/services/image_analysis/scene_features.dart';

class _MockDio extends Mock implements Dio {}

final _photo = Uint8List.fromList([1, 2, 3]);
const _validBody = {'setting': 'city', 'energy': 70, 'confidence': 0.9};

DioException _error(DioExceptionType type, {int? status}) => DioException(
  requestOptions: RequestOptions(),
  type: type,
  response: status == null
      ? null
      : Response(requestOptions: RequestOptions(), statusCode: status),
);

void main() {
  late _MockDio dio;
  late List<Duration> delays;

  setUpAll(() => registerFallbackValue(Uri()));
  setUp(() {
    dio = _MockDio();
    delays = [];
  });

  RemoteImageAnalysisService service({String url = 'https://api.test/'}) =>
      RemoteImageAnalysisService(
        dio,
        baseUrl: url,
        delay: (d) async => delays.add(d),
      );

  void stubPost(List<Object> results) {
    var i = 0;
    when(() => dio.postUri<Object?>(any(), data: any(named: 'data')))
        .thenAnswer((_) async {
          final r = results[i++];
          if (r is DioException) throw r;
          return Response<Object?>(requestOptions: RequestOptions(), data: r);
        });
  }

  test('posts base64 photo to the endpoint and validates the reply', () async {
    stubPost([_validBody]);

    final f = await service().analyzeEnvironment(_photo);

    expect(f.setting, SceneSetting.city);
    expect(f.source, AnalysisSource.remoteModel);
    final captured = verify(
      () => dio.postUri<Object?>(captureAny(), data: captureAny(named: 'data')),
    ).captured;
    expect(captured[0], Uri.parse('https://api.test/v1/analyze-environment'));
    expect((captured[1] as Map)['image'], 'AQID');
  });

  test('retries network errors, then succeeds', () async {
    stubPost([_error(DioExceptionType.connectionError), _validBody]);

    final f = await service().analyzeEnvironment(_photo);

    expect(f.energy, 70);
    expect(delays, hasLength(1));
  });

  test('gives up after maxAttempts with a NetworkFailure', () async {
    stubPost([
      _error(DioExceptionType.receiveTimeout),
      _error(DioExceptionType.badResponse, status: 503),
      _error(DioExceptionType.connectionTimeout),
    ]);

    await expectLater(
      service().analyzeEnvironment(_photo),
      throwsA(isA<NetworkFailure>()),
    );
    expect(delays, hasLength(2));
  });

  test('does not retry client errors', () async {
    stubPost([_error(DioExceptionType.badResponse, status: 400)]);

    await expectLater(
      service().analyzeEnvironment(_photo),
      throwsA(isA<InvalidResponseFailure>()),
    );
    expect(delays, isEmpty);
  });

  test('malformed reply becomes InvalidResponseFailure', () async {
    stubPost([
      {'energy': 'loud'},
    ]);

    await expectLater(
      service().analyzeEnvironment(_photo),
      throwsA(isA<InvalidResponseFailure>()),
    );
  });

  test('refuses non-HTTPS backends without sending anything', () async {
    await expectLater(
      service(url: 'http://api.test/').analyzeEnvironment(_photo),
      throwsA(isA<NotConfiguredFailure>()),
    );
    verifyNever(() => dio.postUri<Object?>(any(), data: any(named: 'data')));
  });
}
