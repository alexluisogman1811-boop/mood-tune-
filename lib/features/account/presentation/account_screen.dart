import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../feedback/application/feedback_controller.dart';
import '../application/account_providers.dart';
import '../data/account_repository.dart';
import '../domain/account.dart';

String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/'
    '${d.year}';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(accountRepositoryProvider);
    if (repo == null) return;
    final lang = context.languageCode;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete your account?')),
        content: Text(
          context.tr(
            'This permanently deletes your login and your plan. Paid time '
            'left is lost. It cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('Delete account')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await repo.deleteAccount();
    } on AccountFailure catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(translate(e.message, lang))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authUserProvider).value;
    final account = ref.watch(accountProvider).value;
    final repo = ref.watch(accountRepositoryProvider);
    final now = ref.watch(clockProvider)();
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(context.tr('Your account'))),
      body: GradientBackground(
        child: SafeArea(
          child: user == null || account == null || repo == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(user.email),
                        subtitle: Text(
                          context.tr(
                            user.emailVerified
                                ? 'Email confirmed'
                                : 'Email not confirmed yet',
                          ),
                        ),
                        trailing: user.emailVerified
                            ? null
                            : TextButton(
                                onPressed: repo.resendVerification,
                                child: Text(context.tr('Resend')),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PlanCard(account: account, now: now),
                    const SizedBox(height: 8),
                    if (!account.isPremium(now) ||
                        account.plan != Plan.lifetime)
                      FilledButton.icon(
                        onPressed: () => context.push(AppRoutes.upgrade),
                        icon: const Icon(Icons.workspace_premium_outlined),
                        label: Text(
                          context.tr(
                            account.isPremium(now)
                                ? 'Renew or change plan'
                                : 'Upgrade to Premium',
                          ),
                        ),
                      ),
                    if (isAdmin) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () => context.push(AppRoutes.admin),
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: Text(context.tr('Admin dashboard')),
                      ),
                    ],
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: repo.signOut,
                      icon: const Icon(Icons.logout),
                      label: Text(context.tr('Sign out')),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: theme.colorScheme.error,
                      ),
                      onPressed: () => _delete(context, ref),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(context.tr('Delete account')),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.account, required this.now});
  final Account account;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final premium = account.isPremium(now);
    final until = account.premiumUntil;
    final left = account.playlistsLeft(now);
    final expired = account.plan.isPaid && !premium;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  premium
                      ? Icons.workspace_premium
                      : Icons.workspace_premium_outlined,
                  color: premium ? theme.colorScheme.primary : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('Plan: {plan}', {
                      'plan': context.tr(
                        expired ? Plan.free.label : account.plan.label,
                      ),
                    }),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(switch (account.plan) {
              _ when expired => context.tr(
                'Your {plan} plan ended on {date}.',
                {
                  'plan': context.tr(account.plan.label),
                  'date': formatDate(until!),
                },
              ),
              Plan.lifetime => context.tr('Premium forever.'),
              Plan.monthly || Plan.yearly => context.tr(
                'Premium until {date}.',
                {'date': formatDate(until!)},
              ),
              Plan.free => context.tr(
                '{left} of {total} free playlists left today.',
                {'left': left, 'total': FreeLimits.playlistsPerDay},
              ),
            }, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
