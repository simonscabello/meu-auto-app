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

    return AppScaffold(
      title: 'Redefinir senha',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          if (_banner != null) AuthFormBanner(message: _banner!),
          Text(
            PasswordResetCopy.linkLifetime,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.s24),
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
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.s24),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: _offline ? 'Tentar de novo' : 'Enviar link',
              loading: _submitting,
              onPressed: _submit,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          AppButton(
            label: 'Voltar ao login',
            variant: AppButtonVariant.tertiary,
            onPressed: _submitting ? null : () => context.go(AppRoutes.login),
          ),
        ],
      ),
    );
  }
}

class PasswordResetRequestSuccess extends StatelessWidget {
  const PasswordResetRequestSuccess({super.key, required this.onBackToLogin});

  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Redefinir senha',
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              PasswordResetCopy.requestAccepted,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.s24),
            AppButton(label: 'Voltar ao login', onPressed: onBackToLogin),
          ],
        ),
      ),
    );
  }
}
