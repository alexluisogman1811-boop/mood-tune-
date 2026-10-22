import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/account/application/account_providers.dart';
import '../features/account/presentation/account_screen.dart';
import '../features/account/presentation/admin_screen.dart';
import '../features/account/presentation/login_screen.dart';
import '../features/account/presentation/upgrade_screen.dart';
import '../features/atmosphere/presentation/analysis_screen.dart';
import '../features/camera/presentation/capture_screen.dart';
import '../features/feedback/presentation/feedback_screen.dart';
import '../features/mood/presentation/mood_screen.dart';
import '../features/music_platform/presentation/platform_screen.dart';
import '../features/onboarding/presentation/privacy_screen.dart';
import '../features/onboarding/presentation/welcome_screen.dart';
import '../features/preferences/presentation/preferences_screen.dart';
import '../features/activity/presentation/activity_screen.dart';
import '../features/recommendations/presentation/results_screen.dart';
import '../features/recommendations/presentation/track_detail_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

/// Route paths, kept in one place so screens never hardcode strings.
abstract final class AppRoutes {
  static const welcome = '/';
  static const privacy = '/privacy';
  static const activity = '/activity';
  static const capture = '/capture';
  static const mood = '/mood';
  static const preferences = '/preferences';
  static const platform = '/platform';
  static const analysis = '/analysis';
  static const results = '/results';
  static const settings = '/settings';
  static const feedback = '/feedback';
  static const login = '/login';
  static const account = '/account';
  static const upgrade = '/upgrade';
  static const admin = '/admin';
  static String track(String id) => '/results/track/${Uri.encodeComponent(id)}';
}

final routerProvider = Provider<GoRouter>((ref) {
  // Re-check where the user may go whenever they sign in or out.
  final authChanged = ValueNotifier(0);
  ref
    ..listen(authUserProvider, (_, _) => authChanged.value++)
    ..onDispose(authChanged.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.welcome,
    refreshListenable: authChanged,
    redirect: (context, state) {
      if (!ref.read(accountsEnabledProvider)) return null;
      final auth = ref.read(authUserProvider);
      if (auth.isLoading) return null;
      final signedIn = auth.value != null;
      final path = state.matchedLocation;
      final open = path == AppRoutes.login || path == AppRoutes.privacy;
      if (!signedIn && !open) return AppRoutes.login;
      if (signedIn && path == AppRoutes.login) return AppRoutes.welcome;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.account,
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: AppRoutes.upgrade,
        builder: (context, state) => const UpgradeScreen(),
      ),
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => const AdminScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.feedback,
        builder: (context, state) => const FeedbackScreen(),
      ),
      GoRoute(
        path: AppRoutes.activity,
        builder: (context, state) => const ActivityScreen(),
      ),
      GoRoute(
        path: AppRoutes.capture,
        builder: (context, state) => const CaptureScreen(),
      ),
      GoRoute(
        path: AppRoutes.mood,
        builder: (context, state) => const MoodScreen(),
      ),
      GoRoute(
        path: AppRoutes.preferences,
        builder: (context, state) => const PreferencesScreen(),
      ),
      GoRoute(
        path: AppRoutes.platform,
        builder: (context, state) => const PlatformScreen(),
      ),
      GoRoute(
        path: AppRoutes.analysis,
        builder: (context, state) => const AnalysisScreen(),
      ),
      GoRoute(
        path: AppRoutes.results,
        builder: (context, state) => const ResultsScreen(),
        routes: [
          GoRoute(
            path: 'track/:id',
            builder: (context, state) =>
                TrackDetailScreen(trackId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
