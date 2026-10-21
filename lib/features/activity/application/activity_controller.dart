import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/activity.dart';

/// What the user is doing this session. Null until they choose.
final activityProvider = NotifierProvider<ActivityController, Activity?>(
  ActivityController.new,
);

class ActivityController extends Notifier<Activity?> {
  @override
  Activity? build() => null;

  void set(Activity activity) => state = activity;

  void reset() => state = null;
}
