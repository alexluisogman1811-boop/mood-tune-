import 'package:flutter/foundation.dart' show compute;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../core/errors/app_failure.dart';

/// Normalises a captured or picked photo for analysis: applies EXIF rotation,
/// downsizes the long edge and re-encodes as JPEG. Re-encoding also drops
/// EXIF metadata such as GPS location before anything can be uploaded.
abstract final class PhotoProcessor {
  static const maxEdge = 1024;
  static const jpegQuality = 80;

  static Future<Uint8List> prepare(Uint8List raw) async {
    // compute(): a background isolate on phones, inline on the web.
    final out = await compute(prepareSync, raw);
    if (out == null) {
      throw const InvalidResponseFailure(
        'That file could not be read as a photo.',
      );
    }
    return out;
  }

  /// Synchronous core, exposed for tests. Returns null for undecodable input.
  static Uint8List? prepareSync(Uint8List raw) {
    final decoded = img.decodeImage(raw);
    if (decoded == null) return null;
    var image = img.bakeOrientation(decoded);
    final longEdge = math.max(image.width, image.height);
    if (longEdge > maxEdge) {
      image = image.width >= image.height
          ? img.copyResize(
              image,
              width: maxEdge,
              interpolation: img.Interpolation.average,
            )
          : img.copyResize(
              image,
              height: maxEdge,
              interpolation: img.Interpolation.average,
            );
    }
    image.exif.clear();
    return img.encodeJpg(image, quality: jpegQuality);
  }
}
