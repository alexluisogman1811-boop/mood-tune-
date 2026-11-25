import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/links/url_opener.dart';
import '../application/feedback_controller.dart';

/// Opens the feedback questions on the web and stops the app asking again.
///
/// The questions used to live in the app, which posted them to a backend
/// that never received them. They are a web page now, so one broken piece
/// cannot lose someone's answers silently.
Future<void> openFeedback(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final failed = context.tr('Could not open the link.');
  final site = ref.read(feedbackSiteProvider);
  if (site == null) {
    messenger.showSnackBar(SnackBar(content: Text(failed)));
    return;
  }
  final ok = await ref.read(urlOpenerProvider)(site);
  if (!ok) {
    messenger.showSnackBar(SnackBar(content: Text(failed)));
    return;
  }
  await ref.read(feedbackPromptProvider.notifier).markAsked();
}
