import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../account/application/account_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/platform/temp_file.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../atmosphere/application/analysis_controller.dart';
import '../application/camera_providers.dart';
import '../application/captured_photo_controller.dart';
import '../data/photo_processor.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  bool _initializing = true;
  bool _busy = false;
  String? _cameraError;
  Uint8List? _review;
  PhotoOrigin? _reviewOrigin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Free plan: photo analysis is Premium, so don't even start the camera.
    if (ref.read(entitlementsProvider).canUsePhoto) {
      _initCamera();
    } else {
      _initializing = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  // The camera plugin does not manage lifecycle itself; release the device
  // when backgrounded and reacquire it on resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (state == AppLifecycleState.inactive) {
      if (camera == null) return;
      setState(() => _camera = null);
      camera.dispose();
    } else if (state == AppLifecycleState.resumed &&
        camera == null &&
        _review == null) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _initializing = true;
      _cameraError = null;
    });
    try {
      final cameras = await ref.read(availableCamerasProvider)();
      if (cameras.isEmpty) {
        _setCameraError('No camera was found on this device.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _initializing = false;
      });
    } on CameraException catch (e) {
      _setCameraError(_cameraMessage(e.code));
    } on PlatformException {
      _setCameraError('The camera is not available on this device.');
    } on MissingPluginException {
      // Platform without a camera implementation.
      _setCameraError('The camera is not available on this device.');
    }
  }

  void _setCameraError(String message) {
    if (!mounted) return;
    setState(() {
      _cameraError = message;
      _initializing = false;
    });
  }

  static String _cameraMessage(String code) => switch (code) {
    'CameraAccessDenied' =>
      'Camera access was denied. You can pick a photo from your gallery '
          'or continue without one.',
    'CameraAccessDeniedWithoutPrompt' =>
      'Camera access is turned off. Enable it in Settings > Privacy > '
          'Camera, or continue without a photo.',
    'CameraAccessRestricted' => 'Camera access is restricted on this device.',
    _ => 'The camera could not be started.',
  };

  Future<void> _takePicture() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final file = await camera.takePicture();
      final raw = await file.readAsBytes();
      // The plugin writes a temp file; remove it so no copy lingers.
      await deleteTempFile(file.path);
      await _processAndReview(raw, PhotoOrigin.camera);
    } on CameraException catch (e) {
      _showError(_cameraMessage(e.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await ref
          .read(imagePickerProvider)
          .pickImage(
            source: ImageSource.gallery,
            maxWidth: 2048,
            maxHeight: 2048,
            requestFullMetadata: false,
          );
      if (file == null) return; // user cancelled
      await _processAndReview(await file.readAsBytes(), PhotoOrigin.gallery);
    } on PlatformException {
      _showError(
        'Could not open your photos. Check photo access in Settings, or '
        'continue without a photo.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _processAndReview(Uint8List raw, PhotoOrigin origin) async {
    try {
      final prepared = await PhotoProcessor.prepare(raw);
      if (!mounted) return;
      setState(() {
        _review = prepared;
        _reviewOrigin = origin;
      });
    } on AppFailure catch (e) {
      _showError(e.message);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.tr(message))));
  }

  void _retake() {
    setState(() {
      _review = null;
      _reviewOrigin = null;
    });
    if (_camera == null && _cameraError == null) _initCamera();
  }

  void _usePhoto() {
    final bytes = _review;
    final origin = _reviewOrigin;
    if (bytes == null || origin == null) return;
    ref
        .read(capturedPhotoProvider.notifier)
        .set(CapturedPhoto(bytes: bytes, origin: origin));
    ref.read(analysisControllerProvider.notifier).reset();
    context.push(AppRoutes.mood);
  }

  void _skip() {
    ref.read(capturedPhotoProvider.notifier).clear();
    ref.read(analysisControllerProvider.notifier).reset();
    context.push(AppRoutes.mood);
  }

  /// Shown to Free users instead of the camera.
  Widget _premiumLock() {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(context.tr('Capture your surroundings'))),
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('Photo analysis is a Premium feature'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      'Premium reads the light, colour and weather around '
                      'you to pick better songs. You can still continue '
                      'with your activity and mood.',
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.push(AppRoutes.upgrade),
                    icon: const Icon(Icons.workspace_premium_outlined),
                    label: Text(context.tr('Upgrade to Premium')),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _skip,
                    child: Text(context.tr('Continue without a photo')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(entitlementsProvider).canUsePhoto) return _premiumLock();
    final review = _review;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(context.tr('Capture your surroundings'))),
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                Text(
                  context.tr(
                    'Point at your environment — the sky, the room, the street. '
                    'We look at light, colour and atmosphere, not people.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: ColoredBox(
                      // Theme surface keeps overlay text readable in light and dark.
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: review != null
                          ? Image.memory(
                              review,
                              fit: BoxFit.contain,
                              semanticLabel: context.tr('Photo you selected'),
                            )
                          : _buildViewfinder(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (review != null)
                  ..._reviewActions()
                else
                  ..._captureActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewfinder() {
    final camera = _camera;
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _cameraError;
    if (error != null || camera == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                context.tr(error ?? 'The camera is paused.'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _initCamera,
                child: Text(context.tr('Try camera again')),
              ),
            ],
          ),
        ),
      );
    }
    return Center(child: CameraPreview(camera));
  }

  List<Widget> _captureActions() {
    final canShoot = _camera?.value.isInitialized ?? false;
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton.filledTonal(
            tooltip: context.tr('Choose from gallery'),
            iconSize: 28,
            onPressed: _busy ? null : _pickFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
          ),
          SizedBox(
            width: 76,
            height: 76,
            child: IconButton.filled(
              tooltip: context.tr('Take photo'),
              iconSize: 36,
              onPressed: canShoot && !_busy ? _takePicture : null,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : const Icon(Icons.camera_alt_outlined),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _skip,
        child: Text(context.tr('Continue without a photo')),
      ),
    ];
  }

  List<Widget> _reviewActions() => [
    FilledButton(
      onPressed: _usePhoto,
      child: Text(context.tr('Use this photo')),
    ),
    const SizedBox(height: 8),
    OutlinedButton(
      onPressed: _retake,
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      child: Text(context.tr('Retake')),
    ),
  ];
}
