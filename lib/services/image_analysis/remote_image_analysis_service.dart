import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/errors/app_failure.dart';
import 'image_analysis_service.dart';
import 'scene_features.dart';

/// Calls the MoodScape analysis backend, which holds the AI provider's secret
/// key. The app itself never sees that key.
///
/// Contract: `POST {baseUrl}/v1/analyze-environment` with
/// `{"image": <base64 jpeg>, "mimeType": "image/jpeg"}`; responds with the
/// scene JSON validated by [SceneFeatures.fromJson].
class RemoteImageAnalysisService implements ImageAnalysisService {
  RemoteImageAnalysisService(
    this._dio, {
    required String baseUrl,
    this.maxAttempts = 3,
    Future<void> Function(Duration)? delay,
  }) : _endpoint = Uri.parse(baseUrl).resolve('v1/analyze-environment'),
       _delay = delay ?? Future<void>.delayed;

  final Dio _dio;
  final Uri _endpoint;
  final int maxAttempts;
  final Future<void> Function(Duration) _delay;

  @override
  bool get isRemote => true;

  @override
  Future<SceneFeatures> analyzeEnvironment(Uint8List jpegBytes) async {
    if (_endpoint.scheme != 'https') {
      throw const NotConfiguredFailure('Analysis backend must use HTTPS.');
    }
    final body = {'image': base64Encode(jpegBytes), 'mimeType': 'image/jpeg'};

    for (var attempt = 1; ; attempt++) {
      try {
        final response = await _dio.postUri<Object?>(_endpoint, data: body);
        return SceneFeatures.fromJson(
          response.data,
          source: AnalysisSource.remoteModel,
        );
      } on DioException catch (e) {
        final failure = _mapError(e);
        final retryable = failure is NetworkFailure;
        if (!retryable || attempt >= maxAttempts) throw failure;
        await _delay(Duration(milliseconds: 500 * attempt * attempt));
      }
    }
  }

  static AppFailure _mapError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return const NetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 503 || status == 429 || status >= 500) {
          return const NetworkFailure(
            'The analysis model is temporarily unavailable.',
          );
        }
        return const InvalidResponseFailure(
          'The analysis service rejected the request.',
        );
      case DioExceptionType.badCertificate:
        return const NetworkFailure('Secure connection failed.');
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return const NetworkFailure();
    }
  }
}
