import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/reading.dart';

/// What the user is reading this session. Null until they choose.
final readingProvider = NotifierProvider<ReadingController, ReadingKind?>(
  ReadingController.new,
);

class ReadingController extends Notifier<ReadingKind?> {
  @override
  ReadingKind? build() => null;

  void set(ReadingKind kind) => state = kind;

  void reset() => state = null;
}
