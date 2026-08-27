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
    if (_succeeded) {
      return AppScaffold(
        title: 'Redefinir senha',
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                PasswordResetCopy.sessionsEnded,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.s24),
              AppButton(
                label: 'Entrar',
                onPressed: () => unawaited(_goToLogin()),
              ),
            ],
          ),
        ),
      );
    }

    if (_invalidLink && _fieldErrors.isEmpty) {
      return AppScaffold(
        title: 'Redefinir senha',
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _banner ?? 'Link de redefinição inválido ou expirado.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.s24),
              AppButton(
                label: 'Pedir outro link',
                onPressed: () => context.go(AppRoutes.passwordReset),
              ),
            ],
          ),
        ),
      );
    }

    return AppScaffold(
      title: 'Redefinir senha',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          if (_banner != null) AuthFormBanner(message: _banner!),
          AuthPasswordField(
            controller: _passwordController,
            label: 'Nova senha',
            hint: 'Mínimo de 8 caracteres. Sem exigência de símbolo ou número.',
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
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: _offline ? 'Tentar de novo' : 'Redefinir senha',
              loading: _submitting,
              onPressed: _canSubmit ? _submit : null,
            ),
          ),
        ],
      ),
    );
  }
}
