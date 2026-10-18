// Resizes assets/icon/icon.png into the web app icons.
//
//   dart run tool/generate_web_icons.dart
//
// The artwork keeps the orb well inside the central safe zone, so the same
// opaque image also serves as the maskable icon.
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final source = img.decodePng(File('assets/icon/icon.png').readAsBytesSync())!;
  const outputs = {
    'web/favicon.png': 32,
    'web/icons/apple-touch-icon.png': 180,
    'web/icons/Icon-192.png': 192,
    'web/icons/Icon-512.png': 512,
    'web/icons/Icon-maskable-192.png': 192,
    'web/icons/Icon-maskable-512.png': 512,
  };
  for (final MapEntry(key: path, value: size) in outputs.entries) {
    final resized = img.copyResize(
      source,
      width: size,
      height: size,
      interpolation: img.Interpolation.average,
    );
    File(path).writeAsBytesSync(img.encodePng(resized));
  }
  stdout.writeln('Wrote ${outputs.length} web icons.');
}
