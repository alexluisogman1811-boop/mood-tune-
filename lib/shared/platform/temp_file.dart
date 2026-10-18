/// Deletes a temporary file written by a plugin (e.g. the camera).
/// On the web there are no temporary files, so this does nothing there.
library;

export 'temp_file_io.dart' if (dart.library.js_interop) 'temp_file_web.dart';
