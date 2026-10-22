import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';

/// Delivers one feedback entry (already JSON) to wherever it is collected.
abstract interface class FeedbackSender {
  Future<void> send(Map<String, Object?> json);
}

/// Posts to the Google Apps Script web app in tool/feedback_backend.
/// Sent as text/plain so browsers make a "simple" request with no CORS
/// preflight, which Apps Script cannot answer.
class HttpFeedbackSender implements FeedbackSender {
  HttpFeedbackSender(this._dio, this._url);

  final Dio _dio;
  final Uri _url;

  @override
  Future<void> send(Map<String, Object?> json) async {
    try {
      var r = await _dio.postUri<String>(
        _url,
        data: jsonEncode(json),
        options: Options(
          contentType: 'text/plain',
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (s) => s != null && s < 400,
        ),
      );
      // Apps Script answers a POST with a redirect to the result. Browsers
      // follow it themselves; on phones we fetch it.
      final location = r.headers.value('location');
      if ((r.statusCode ?? 0) >= 300 && location != null) {
        r = await _dio.getUri<String>(
          Uri.parse(location),
          options: Options(responseType: ResponseType.plain),
        );
      }
      if (!'${r.data}'.contains('"ok":true')) {
        throw const InvalidResponseFailure('Feedback was not accepted.');
      }
    } on DioException {
      throw const NetworkFailure();
    }
  }
}
