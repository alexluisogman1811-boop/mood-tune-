import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:moodscape/features/camera/data/photo_processor.dart';

Uint8List _png(int w, int h) => img.encodePng(img.Image(width: w, height: h));

void main() {
  test('downsizes landscape photos to the max edge', () {
    final out = img.decodeJpg(PhotoProcessor.prepareSync(_png(3000, 1500))!)!;
    expect(out.width, PhotoProcessor.maxEdge);
    expect(out.height, 512);
  });

  test('downsizes portrait photos by height', () {
    final out = img.decodeJpg(PhotoProcessor.prepareSync(_png(800, 2048))!)!;
    expect(out.height, PhotoProcessor.maxEdge);
    expect(out.width, 400);
  });

  test('leaves small photos at their size but re-encodes as JPEG', () {
    final bytes = PhotoProcessor.prepareSync(_png(320, 240))!;
    expect(img.JpegDecoder().isValidFile(bytes), isTrue);
    final out = img.decodeJpg(bytes)!;
    expect((out.width, out.height), (320, 240));
  });

  test('returns null for non-image data', () {
    expect(PhotoProcessor.prepareSync(Uint8List.fromList([0, 1, 2])), isNull);
  });
}
