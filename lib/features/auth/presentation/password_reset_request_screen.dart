import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/data/auth_repository.dart';
import 'package:meu_auto/features/auth/domain/password_reset_copy.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';

class PasswordResetRequestScreen extends ConsumerStatefulWidget {
  const PasswordResetRequestScreen({super.key});

  @override
  ConsumerState<PasswordResetRequestScreen> createState() =>
      _PasswordResetRequestScreenState();
}

class _PasswordResetRequestScreenState
    extends ConsumerState<PasswordResetRequestScreen> {
  final _emailController = TextEditingController();
  bool _submitting = false;
  bool _accepted = false;
  bool _offline = false;
  String? _banner;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _banner = null;
      _offline = false;
      _fieldErrors = {};
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(email: _emailController.text.trim());
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _accepted = true;
      });
    } on ApiFailure catch (failure) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _fieldErrors = ApiFormErrors.fieldsOf(failure);
        _banner = ApiFormErrors.bannerOf(failure);
        _offline = ApiFormErrors.isOffline(failure);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _banner = 'Algo deu errado. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_accepted) {
      return PasswordResetRequestSuccess(
        onBackToLogin: () => context.go(AppRoutes.login),
      );
    }

    final theme = Theme.of(context);
    // The entry screens replace each other rather than stack; the arrow goes
    // back to the sign-in, which is where "back" leads from here.
    return AppScaffold(
      title: 'Redefinir senha',
      leading: BackButton(
        onPressed: _submitting ? null : () => context.go(AppRoutes.login),
      ),
      body: ListView(
        padding: AppSpacing.screenHeaded,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Text(
            PasswordResetCopy.linkLifetime,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s24),
          if (_banner != null) AuthFormBanner(message: _banner!),
          TextField(
            controller: _emailController,
            enabled: !_submitting,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.email],
            inputFormatters: [LengthLimitingTextInputFormatter(254)],
            onSubmitted: (_) {
              if (!_submitting) {
                unawaited(_submit());
              }
            },
            onChanged: (_) {
              if (_fieldErrors.containsKey('email')) {
                setState(() => _fieldErrors.remove('email'));
              }
            },
            decoration: InputDecoration(
              labelText: 'E-mail',
              errorText: _fieldErrors['email'],
            ),
          ),
          const SizedBox(height: AppSpacing.s24),
          AppButton(
            label: _offline ? 'Tentar de novo' : 'Enviar link',
            loading: _submitting,
            onPressed: _submit,
            expanded: true,
          ),
        ],
      ),
    );
  }
}

/// After the request, whatever the address was.
///
/// The words are the same whether or not an account exists — anything warmer
/// ("enviamos para você") would tell a stranger which e-mails are registered.
class PasswordResetRequestSuccess extends StatelessWidget {
  const PasswordResetRequestSuccess({super.key, required this.onBackToLogin});

  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Redefinir senha',
      leading: BackButton(onPressed: onBackToLogin),
      body: ListView(
        padding: AppSpacing.screenHeaded,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Confira seu e-mail',
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            '${PasswordResetCopy.requestAccepted}.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s32),
          AppButton(
            label: 'Voltar ao login',
            onPressed: onBackToLogin,
            expanded: true,
          ),
        ],
      ),
    );
  }
}
