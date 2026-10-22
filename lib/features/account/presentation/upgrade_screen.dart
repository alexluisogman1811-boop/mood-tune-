import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/configuration/config_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../application/account_providers.dart';
import '../domain/account.dart';

/// Plans, prices and how to pay. Payment is manual: the user pays the
/// owner, who switches the plan on in the admin dashboard.
class UpgradeScreen extends ConsumerWidget {
  const UpgradeScreen({super.key});

  static const _benefits = [
    (Icons.all_inclusive, 'Unlimited playlists every day'),
    (Icons.photo_camera_outlined, 'Photo analysis of your surroundings'),
    (Icons.queue_music_outlined, 'Playlists of 20 or 30 songs'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final email = ref.watch(authUserProvider).value?.email ?? '';
    final config = ref.watch(appConfigProvider);
    final paymentInfo = config.paymentInfo;
    final lineId = config.lineId;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(context.tr('MoodScape Premium'))),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                context.tr('Unlock everything'),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              for (final (icon, text) in _benefits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(icon, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(child: Text(context.tr(text))),
                    ],
                  ),
                ),
              Text(
                context.tr(
                  'Free: {count} playlists a day, 10 songs, no photo.',
                  {'count': FreeLimits.playlistsPerDay},
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              for (final plan in Plan.values.where((p) => p.isPaid))
                _PlanTile(plan: plan),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('How to pay'),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        paymentInfo.isNotEmpty
                            ? paymentInfo
                            : lineId.isNotEmpty
                            ? context.tr(
                                'Message us on LINE for payment details: '
                                'PromptPay, bank transfer or PayPal.',
                              )
                            : context.tr(
                                'Payment details are not set up in this '
                                'build yet.',
                              ),
                      ),
                      if (lineId.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.chat_outlined),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SelectableText(
                                context.tr('LINE ID: {id}', {'id': lineId}),
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        context.tr(
                          '1. Pay for the plan you want.\n'
                          '2. Send the payment slip together with your '
                          'account email.\n'
                          '3. Your plan is switched on, usually within a day.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.tr('Your account email'),
                        style: theme.textTheme.labelLarge,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              email,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: context.tr('Copy email'),
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final copied = context.tr('Copied.');
                              await Clipboard.setData(
                                ClipboardData(text: email),
                              );
                              messenger.showSnackBar(
                                SnackBar(content: Text(copied)),
                              );
                            },
                            icon: const Icon(Icons.copy),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan});
  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final best = plan == Plan.yearly;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: best ? theme.colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(context.tr(plan.label), style: theme.textTheme.titleMedium),
        subtitle: Text(
          context.tr(switch (plan) {
            Plan.monthly => 'Premium for 30 days',
            Plan.yearly => 'Premium for 365 days · best value',
            _ => 'Pay once, Premium forever',
          }),
        ),
        trailing: Text(
          '${plan.price}',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
