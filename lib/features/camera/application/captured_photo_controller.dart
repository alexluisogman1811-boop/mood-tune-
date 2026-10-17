import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PhotoOrigin { camera, gallery }

/// A resized JPEG held in memory only. It is never written to app storage.
class CapturedPhoto {
  const CapturedPhoto({required this.bytes, required this.origin});
  final Uint8List bytes;
  final PhotoOrigin origin;
}

final capturedPhotoProvider =
    NotifierProvider<CapturedPhotoController, CapturedPhoto?>(
      CapturedPhotoController.new,
    );

class CapturedPhotoController extends Notifier<CapturedPhoto?> {
  @override
  CapturedPhoto? build() => null;

  void set(CapturedPhoto photo) => state = photo;

  void clear() => state = null;
}
