import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/l10n/app_language.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../application/account_providers.dart';
import '../data/account_repository.dart';

/// Sign in or create an account. Shown before anything else when accounts
/// are switched on.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final repo = ref.read(accountRepositoryProvider);
    if (repo == null) return;
    final lang = context.languageCode;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_creating) {
        await repo.signUp(_email.text, _password.text);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              translate(
                'Account created. We sent you an email to confirm your '
                'address.',
                lang,
              ),
            ),
          ),
        );
      } else {
        await repo.signIn(_email.text, _password.text);
      }
      // The router moves on once the sign-in is seen.
    } on AccountFailure catch (e) {
      if (mounted) setState(() => _error = translate(e.message, lang));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final repo = ref.read(accountRepositoryProvider);
    final email = _email.text.trim();
    final lang = context.languageCode;
    if (repo == null) return;
    if (!email.contains('@')) {
      setState(
        () =>
            _error = translate('Type your email first, then tap again.', lang),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.sendPasswordReset(email);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            translate(
              'If that email has an account, a reset link is on '
              'its way.',
              lang,
            ),
          ),
        ),
      );
    } on AccountFailure catch (e) {
      if (mounted) setState(() => _error = translate(e.message, lang));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thai = context.languageCode == 'th';
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => ref
                              .read(appLanguageProvider.notifier)
                              .set(
                                thai ? AppLanguage.english : AppLanguage.thai,
                              ),
                          icon: const Icon(Icons.translate, size: 18),
                          label: Text(thai ? 'English' : 'ไทย'),
                        ),
                      ),
                      const Icon(
                        Icons.graphic_eq,
                        size: 56,
                        color: AppColors.glow,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'MoodScape',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr(
                          _creating
                              ? 'Create your free account'
                              : 'Sign in to continue',
                        ),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          labelText: context.tr('Email'),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => (v ?? '').contains('@')
                            ? null
                            : context.tr('That email address is not valid.'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        obscureText: !_showPassword,
                        autofillHints: [
                          _creating
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: context.tr('Password'),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: context.tr(
                              _showPassword ? 'Hide password' : 'Show password',
                            ),
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (v) => (v ?? '').length >= 6
                            ? null
                            : context.tr(
                                'Use a password of at least 6 characters.',
                              ),
                      ),
                      if (_error case final error?) ...[
                        const SizedBox(height: 12),
                        Text(
                          error,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(
                          context.tr(_creating ? 'Create account' : 'Sign in'),
                        ),
                      ),
                      if (!_creating)
                        TextButton(
                          onPressed: _busy ? null : _forgot,
                          child: Text(context.tr('Forgot password?')),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _creating = !_creating;
                                _error = null;
                              }),
                        child: Text(
                          context.tr(
                            _creating
                                ? 'I already have an account'
                                : 'Create a new account',
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        context.tr(
                          'We store only your email, your plan and how many '
                          'playlists you made today. Photos never leave your '
                          'phone. You can delete your account at any time.',
                        ),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.privacy),
                        child: Text(context.tr('How we handle your photos')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
