// Generates MoodScape's launcher icon artwork.
//
//   dart run tool/generate_icon.dart
//   dart run flutter_launcher_icons
//
// Writes assets/icon/icon.png (full icon, opaque) and
// assets/icon/foreground.png (transparent, for Android adaptive icons).
// The design mirrors the in-app logo: a glowing violet orb with a sound-wave
// mark on the night gradient from lib/app/theme/app_theme.dart.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _size = 1024;
const _ss = 2; // supersampling factor for smooth edges

// Brand colours (see AppColors).
const _night = (0x0E, 0x0C, 0x1A);
const _plum = (0x2A, 0x1F, 0x3D);
const _seed = (0x7C, 0x6C, 0xF2);
const _glow = (0xB6, 0xA8, 0xFF);

(int, int, int) _lerp((int, int, int) a, (int, int, int) b, double t) => (
  (a.$1 + (b.$1 - a.$1) * t).round(),
  (a.$2 + (b.$2 - a.$2) * t).round(),
  (a.$3 + (b.$3 - a.$3) * t).round(),
);

void main() {
  Directory('assets/icon').createSync(recursive: true);
  _write(
    _render(withBackground: true, orbRadius: 0.32),
    'assets/icon/icon.png',
  );
  _write(
    _render(withBackground: false, orbRadius: 0.40),
    'assets/icon/foreground.png',
  );
  stdout.writeln('Wrote assets/icon/icon.png and assets/icon/foreground.png');
}

void _write(img.Image big, String path) {
  final out = img.copyResize(
    big,
    width: _size,
    height: _size,
    interpolation: img.Interpolation.average,
  );
  File(path).writeAsBytesSync(img.encodePng(out));
}

img.Image _render({required bool withBackground, required double orbRadius}) {
  final n = _size * _ss;
  final im = img.Image(width: n, height: n, numChannels: 4);
  final c = n / 2;
  final r = n * orbRadius;

  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      var (cr, cg, cb) = (0, 0, 0);
      var alpha = 0;

      if (withBackground) {
        // Diagonal night → plum gradient.
        (cr, cg, cb) = _lerp(_night, _plum, (x + y) / (2 * n));
        alpha = 255;
      }

      final d = math.sqrt((x - c) * (x - c) + (y - c) * (y - c));
      // Soft halo around the orb.
      if (d > r && d < r * 1.45) {
        final t = 1 - (d - r) / (r * 0.45);
        final a = (t * t * 0.55 * 255).round();
        final (hr, hg, hb) = _seed;
        if (withBackground) {
          final k = a / 255;
          cr = (cr + (hr - cr) * k).round();
          cg = (cg + (hg - cg) * k).round();
          cb = (cb + (hb - cb) * k).round();
        } else {
          (cr, cg, cb) = (hr, hg, hb);
          alpha = a;
        }
      }
      // The orb: seed → glow gradient, lit from the top left.
      if (d <= r) {
        final t = ((x - (c - r)) + (y - (c - r))) / (4 * r);
        (cr, cg, cb) = _lerp(_glow, _seed, t.clamp(0.0, 1.0));
        alpha = 255;
      }
      im.setPixelRgba(x, y, cr, cg, cb, alpha);
    }
  }

  // Sound-wave mark: five rounded white bars.
  const heights = [0.30, 0.62, 0.95, 0.62, 0.30];
  final barW = r * 0.16;
  final gap = r * 0.11;
  final total = heights.length * barW + (heights.length - 1) * gap;
  for (var i = 0; i < heights.length; i++) {
    final h = r * 1.05 * heights[i];
    final left = c - total / 2 + i * (barW + gap);
    final top = c - h / 2;
    final white = img.ColorRgba8(255, 255, 255, 255);
    img.fillRect(
      im,
      x1: left.round(),
      y1: (top + barW / 2).round(),
      x2: (left + barW).round(),
      y2: (top + h - barW / 2).round(),
      color: white,
    );
    for (final cy in [top + barW / 2, top + h - barW / 2]) {
      img.fillCircle(
        im,
        x: (left + barW / 2).round(),
        y: cy.round(),
        radius: (barW / 2).round(),
        color: white,
      );
    }
  }
  return im;
}
