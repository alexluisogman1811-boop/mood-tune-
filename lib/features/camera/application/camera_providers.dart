import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Injectable so widget tests can simulate devices without a camera.
final availableCamerasProvider =
    Provider<Future<List<CameraDescription>> Function()>(
      (ref) => availableCameras,
    );

final imagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());
