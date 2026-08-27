import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/auth/presentation/auth_password_field.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  bool _offline = false;
  String? _banner;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
          .read(authControllerProvider.notifier)
          .register(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      TextInput.finishAutofillContext();
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
    return AppScaffold(
      title: 'Criar conta',
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            if (_banner != null) AuthFormBanner(message: _banner!),
            TextField(
              controller: _nameController,
              enabled: !_submitting,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              inputFormatters: [LengthLimitingTextInputFormatter(120)],
              onChanged: (_) {
                if (_fieldErrors.containsKey('name')) {
                  setState(() => _fieldErrors.remove('name'));
                }
              },
              decoration: InputDecoration(
                labelText: 'Nome',
                errorText: _fieldErrors['name'],
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            TextField(
              controller: _emailController,
              enabled: !_submitting,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.email],
              inputFormatters: [LengthLimitingTextInputFormatter(254)],
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
            const SizedBox(height: AppSpacing.s16),
            AuthPasswordField(
              controller: _passwordController,
              label: 'Senha',
              hint:
                  'Mínimo de 8 caracteres. Sem exigência de símbolo ou número.',
              enabled: !_submitting,
              autofillHints: const [AutofillHints.newPassword],
              errorText: _fieldErrors['password'],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_submitting) {
                  unawaited(_submit());
                }
              },
              onChanged: (_) {
                if (_fieldErrors.containsKey('password')) {
                  setState(() => _fieldErrors.remove('password'));
                }
              },
            ),
            const SizedBox(height: AppSpacing.s24),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: _offline ? 'Tentar de novo' : 'Criar conta',
                loading: _submitting,
                onPressed: _submit,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            TextButton(
              onPressed: _submitting ? null : () => context.go(AppRoutes.login),
              child: const Text('Já tem conta? Entrar'),
            ),
          ],
        ),
      ),
    );
  }
}
