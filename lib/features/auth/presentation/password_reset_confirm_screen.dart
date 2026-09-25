import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/network/api_error_code.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/data/auth_repository.dart';
import 'package:meu_auto/features/auth/domain/password_reset_copy.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/auth/presentation/auth_password_field.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';

class PasswordResetConfirmScreen extends ConsumerStatefulWidget {
  const PasswordResetConfirmScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<PasswordResetConfirmScreen> createState() =>
      _PasswordResetConfirmScreenState();
}

class _PasswordResetConfirmScreenState
    extends ConsumerState<PasswordResetConfirmScreen> {
  final _passwordController = TextEditingController();
  bool _submitting = false;
  bool _succeeded = false;
  bool _offline = false;
  bool _invalidLink = false;
  String? _banner;
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _invalidLink = widget.token.trim().isEmpty;
    if (_invalidLink) {
      _banner = 'Link de redefinição inválido ou expirado.';
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _passwordController.text.length >= 8 && !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }
    setState(() {
      _submitting = true;
      _banner = null;
      _offline = false;
      _fieldErrors = {};
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .confirmPasswordReset(
            token: widget.token,
            password: _passwordController.text,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _succeeded = true;
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
        _invalidLink = failure.code == ApiErrorCode.unauthorized;
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

  Future<void> _goToLogin() async {
    await ref.read(authControllerProvider.notifier).clearLocalSession();
    if (!mounted) {
      return;
    }
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_succeeded) {
      return _ResetOutcome(
        title: 'Senha redefinida',
        message: 'Todos os aparelhos saíram da conta. Entre com a nova senha.',
        actionLabel: 'Entrar',
        onAction: () => unawaited(_goToLogin()),
      );
    }

    if (_invalidLink && _fieldErrors.isEmpty) {
      return _ResetOutcome(
        title: 'Link inválido ou expirado',
        message: PasswordResetCopy.linkLifetime,
        actionLabel: 'Pedir outro link',
        onAction: () => context.go(AppRoutes.passwordReset),
      );
    }

    return AppScaffold(
      title: 'Redefinir senha',
      body: ListView(
        padding: AppSpacing.screenHeaded,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Text(
            PasswordResetCopy.signsOutEverywhere,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s24),
          if (_banner != null) AuthFormBanner(message: _banner!),
          AuthPasswordField(
            controller: _passwordController,
            label: 'Nova senha',
            hint: newPasswordHint,
            enabled: !_submitting,
            autofillHints: const [AutofillHints.newPassword],
            errorText: _fieldErrors['password'],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (_canSubmit) {
                unawaited(_submit());
              }
            },
            onChanged: (_) {
              setState(() {
                if (_fieldErrors.containsKey('password')) {
                  _fieldErrors.remove('password');
                }
              });
            },
          ),
          const SizedBox(height: AppSpacing.s24),
          AppButton(
            label: _offline ? 'Tentar de novo' : 'Redefinir senha',
            loading: _submitting,
            onPressed: _canSubmit ? _submit : null,
            expanded: true,
          ),
        ],
      ),
    );
  }
}

/// Where the link leads when there is nothing left to type: what happened,
/// in a heading and one sentence, and the one way on.
class _ResetOutcome extends StatelessWidget {
  const _ResetOutcome({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Redefinir senha',
      body: ListView(
        padding: AppSpacing.screenHeaded,
        children: [
          Semantics(
            container: true,
            header: true,
            child: Text(title, style: theme.textTheme.headlineSmall),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s32),
          AppButton(label: actionLabel, onPressed: onAction, expanded: true),
        ],
      ),
    );
  }
}
