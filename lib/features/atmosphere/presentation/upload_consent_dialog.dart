import 'package:material_ui/material_ui.dart';

class UploadConsentResult {
  const UploadConsentResult({required this.allow, required this.remember});
  final bool allow;
  final bool remember;
}

/// Asks before any photo leaves the device. Dismissing counts as "no".
Future<UploadConsentResult> showUploadConsentDialog(
  BuildContext context,
) async {
  final result = await showDialog<UploadConsentResult>(
    context: context,
    builder: (_) => const _UploadConsentDialog(),
  );
  return result ?? const UploadConsentResult(allow: false, remember: false);
}

class _UploadConsentDialog extends StatefulWidget {
  const _UploadConsentDialog();

  @override
  State<_UploadConsentDialog> createState() => _UploadConsentDialogState();
}

class _UploadConsentDialogState extends State<_UploadConsentDialog> {
  bool _remember = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send photo for AI analysis?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your resized photo (location data removed) is sent over HTTPS to '
            'the MoodScape analysis service to describe the scene. It is not '
            'stored after the analysis.\n\nIf you decline, we use basic '
            'on-device analysis instead.',
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _remember,
            onChanged: (v) => setState(() => _remember = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Remember my choice'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context)
                  .pop(UploadConsentResult(allow: false, remember: _remember)),
          child: const Text('On device only'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context)
                  .pop(UploadConsentResult(allow: true, remember: _remember)),
          child: const Text('Allow upload'),
        ),
      ],
    );
  }
}
