import 'dart:io';

/// Best-effort delete; a missing or locked file is not an error.
Future<void> deleteTempFile(String path) async {
  try {
    await File(path).delete();
  } on FileSystemException {
    // Already gone or not deletable; nothing sensitive is retained by us.
  }
}
