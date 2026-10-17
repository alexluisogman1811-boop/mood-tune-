import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moodscape/app/router.dart';
import 'package:moodscape/core/privacy/photo_consent.dart';
import 'package:moodscape/core/storage/storage_providers.dart';
import 'package:moodscape/features/atmosphere/application/analysis_controller.dart';
import 'package:moodscape/features/atmosphere/domain/atmosphere_analyzer.dart';
import 'package:moodscape/features/atmosphere/presentation/analysis_screen.dart';
import 'package:moodscape/features/camera/application/captured_photo_controller.dart';
import 'package:moodscape/services/image_analysis/mock_image_analysis_service.dart';
import 'package:moodscape/services/image_analysis/scene_features.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _local = SceneFeatures(
  setting: SceneSetting.unknown,
  lighting: SceneLighting.warm,
  atmosphere: {SceneAtmosphere.cozy},
  cues: {},
  energy: 30,
  confidence: 0.35,
  source: AnalysisSource.onDevice,
);

class _Setup {
  _Setup(this.container, this.local, this.remote);
  final ProviderContainer container;
  final MockImageAnalysisService local;
  final MockImageAnalysisService? remote;
}

Future<_Setup> _pump(
  WidgetTester tester, {
  bool withPhoto = true,
  bool withRemote = true,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final local = MockImageAnalysisService(result: _local);
  final remote = withRemote ? MockImageAnalysisService(isRemote: true) : null;

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      atmosphereAnalyzerProvider.overrideWithValue(
        AtmosphereAnalyzer(local: local, remote: remote),
      ),
    ],
  );
  addTearDown(container.dispose);
  if (withPhoto) {
    container
        .read(capturedPhotoProvider.notifier)
        .set(
          CapturedPhoto(
            bytes: Uint8List.fromList([1, 2, 3]),
            origin: PhotoOrigin.camera,
          ),
        );
  }

  final router = GoRouter(
    initialLocation: AppRoutes.analysis,
    routes: [
      GoRoute(
        path: AppRoutes.analysis,
        builder: (_, _) => const AnalysisScreen(),
      ),
      GoRoute(
        path: AppRoutes.results,
        builder: (_, _) => const Scaffold(body: Text('results-page')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump(); // post-frame callback starts the analysis
  return _Setup(container, local, remote);
}

Future<void> _settle(WidgetTester tester) async {
  // The progress view pulses forever, so pump a bounded amount of time.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('no photo: finishes with a mood-only notice', (tester) async {
    final s = await _pump(tester, withPhoto: false);
    await _settle(tester);

    expect(find.textContaining('mood only'), findsOneWidget);
    expect(s.remote!.calls + s.local.calls, 0);
    expect(find.text('See my music'), findsOneWidget);
  });

  testWidgets('asks for consent before uploading; declining stays local', (
    tester,
  ) async {
    final s = await _pump(tester);
    await _settle(tester);

    expect(find.text('Send photo for AI analysis?'), findsOneWidget);
    await tester.tap(find.text('On device only'));
    await _settle(tester);

    expect(s.remote!.calls, 0);
    expect(s.local.calls, 1);
    expect(find.text('Your atmosphere'), findsWidgets);
    expect(find.textContaining('Basic on-device analysis'), findsOneWidget);
    // Not remembered unless the box is ticked.
    expect(s.container.read(photoUploadConsentProvider), isNull);
  });

  testWidgets('allowing upload with "remember" stores consent', (tester) async {
    final s = await _pump(tester);
    await _settle(tester);

    await tester.tap(find.text('Remember my choice'));
    await tester.pump();
    await tester.tap(find.text('Allow upload'));
    await _settle(tester);

    expect(s.remote!.calls, 1);
    expect(s.container.read(photoUploadConsentProvider), isTrue);
  });

  testWidgets('remembered refusal skips the dialog', (tester) async {
    final s = await _pump(
      tester,
      prefs: {'privacy.photo_upload_consent': false},
    );
    await _settle(tester);

    expect(find.text('Send photo for AI analysis?'), findsNothing);
    expect(s.remote!.calls, 0);
    expect(s.local.calls, 1);
  });

  testWidgets('no backend configured: analyses on device, no dialog', (
    tester,
  ) async {
    final s = await _pump(tester, withRemote: false);
    await _settle(tester);

    expect(find.text('Send photo for AI analysis?'), findsNothing);
    expect(s.local.calls, 1);
  });
}
