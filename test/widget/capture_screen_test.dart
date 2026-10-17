import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moodscape/app/router.dart';
import 'package:moodscape/features/camera/application/camera_providers.dart';
import 'package:moodscape/features/camera/presentation/capture_screen.dart';

Future<void> _pump(
  WidgetTester tester,
  Future<List<CameraDescription>> Function() cameras,
) async {
  final router = GoRouter(
    initialLocation: AppRoutes.capture,
    routes: [
      GoRoute(
        path: AppRoutes.capture,
        builder: (_, _) => const CaptureScreen(),
      ),
      GoRoute(
        path: AppRoutes.mood,
        builder: (_, _) => const Scaffold(body: Text('mood-page')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [availableCamerasProvider.overrideWithValue(cameras)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('device without a camera still offers gallery and skip', (
    tester,
  ) async {
    await _pump(tester, () async => []);

    expect(find.text('No camera was found on this device.'), findsOneWidget);
    expect(find.byTooltip('Choose from gallery'), findsOneWidget);
    expect(find.text('Continue without a photo'), findsOneWidget);
    final shutter = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.camera_alt_outlined),
    );
    expect(shutter.onPressed, isNull);
  });

  testWidgets('permission denial shows an explanation', (tester) async {
    await _pump(
      tester,
      () async => throw CameraException('CameraAccessDenied', 'denied'),
    );

    expect(find.textContaining('Camera access was denied'), findsOneWidget);
    expect(find.text('Try camera again'), findsOneWidget);
  });

  testWidgets('missing plugin is handled instead of crashing', (tester) async {
    await _pump(tester, () async => throw MissingPluginException());

    expect(
      find.text('The camera is not available on this device.'),
      findsOneWidget,
    );
  });

  testWidgets('skipping the photo continues to mood selection', (tester) async {
    await _pump(tester, () async => []);

    await tester.tap(find.text('Continue without a photo'));
    await tester.pumpAndSettle();

    expect(find.text('mood-page'), findsOneWidget);
  });
}
