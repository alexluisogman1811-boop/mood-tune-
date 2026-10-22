import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/l10n.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../feedback/application/feedback_controller.dart';
import '../application/account_providers.dart';
import '../data/account_repository.dart';
import '../domain/account.dart';
import 'account_screen.dart' show formatDate;

final _allAccountsProvider = StreamProvider.autoDispose<List<Account>>((ref) {
  final repo = ref.watch(accountRepositoryProvider);
  return repo == null ? Stream.value(const []) : repo.watchAllAccounts();
});

/// Owner-only: every user, their plan, and one tap to change it. The
/// database rules reject these reads and writes for anyone else.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  String _query = '';

  Future<void> _changePlan(Account account) async {
    final repo = ref.read(accountRepositoryProvider);
    if (repo == null) return;
    final lang = context.languageCode;
    final messenger = ScaffoldMessenger.of(context);
    final plan = await showModalBottomSheet<Plan>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                account.email,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final p in Plan.values)
              ListTile(
                leading: Icon(
                  p == Plan.free
                      ? Icons.remove_circle_outline
                      : Icons.workspace_premium_outlined,
                ),
                title: Text(
                  p.isPaid
                      ? context.tr('Give {plan} ({price})', {
                          'plan': context.tr(p.label),
                          'price': p.price,
                        })
                      : context.tr('Set back to Free'),
                ),
                onTap: () => Navigator.of(context).pop(p),
              ),
          ],
        ),
      ),
    );
    if (plan == null) return;
    try {
      await repo.setPlan(account, plan, ref.read(clockProvider)());
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            translate('{email} is now on {plan}.', lang, {
              'email': account.email,
              'plan': translate(plan.label, lang),
            }),
          ),
        ),
      );
    } on AccountFailure catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(translate(e.message, lang))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider)();
    final accounts = ref.watch(_allAccountsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(context.tr('Admin dashboard'))),
      body: GradientBackground(
        child: SafeArea(
          child: switch (accounts) {
            AsyncData(:final value) => _body(context, theme, value, now),
            AsyncError() => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.tr(
                    'Could not load users. Only the admin account can see '
                    'this page.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    ThemeData theme,
    List<Account> all,
    DateTime now,
  ) {
    final active = all.where((a) => a.isPremium(now)).toList();
    int count(Plan p) => active.where((a) => a.plan == p).length;
    final today = Account.dayKey(now);
    final usedToday = all.where((a) => a.usageDate == today).length;
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? all
        : all.where((a) => a.email.toLowerCase().contains(q)).toList();

    Widget stat(String label, String value) => Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(context.tr(label), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(
          children: [
            stat('Users', '${all.length}'),
            stat('Premium now', '${active.length}'),
            stat('Active today', '$usedToday'),
          ],
        ),
        Row(
          children: [
            stat('Monthly', '${count(Plan.monthly)}'),
            stat('Yearly', '${count(Plan.yearly)}'),
            stat('Lifetime', '${count(Plan.lifetime)}'),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            labelText: context.tr('Search by email'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.tr('No users yet.'),
              textAlign: TextAlign.center,
            ),
          ),
        for (final a in shown)
          Card(
            child: ListTile(
              onTap: () => _changePlan(a),
              leading: Icon(
                a.isPremium(now)
                    ? Icons.workspace_premium
                    : Icons.person_outline,
                color: a.isPremium(now) ? theme.colorScheme.primary : null,
              ),
              title: Text(a.email),
              subtitle: Text(
                [
                  context.tr(
                    a.plan.isPaid && !a.isPremium(now)
                        ? 'Expired'
                        : a.plan.label,
                  ),
                  if (a.premiumUntil case final until?)
                    context.tr('until {date}', {'date': formatDate(until)}),
                  context.tr('{count} today', {'count': a.usedToday(now)}),
                ].join(' · '),
              ),
              trailing: const Icon(Icons.edit_outlined),
            ),
          ),
      ],
    );
  }
}
