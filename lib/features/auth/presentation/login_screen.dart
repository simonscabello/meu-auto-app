import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/application/login_notice.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/auth/presentation/auth_password_field.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  bool _offline = false;
  String? _banner;
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final notice = ref.read(loginNoticeProvider);
      if (notice == null) {
        return;
      }
      ref.read(loginNoticeProvider.notifier).state = null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(notice)));
    });
  }

  @override
  void dispose() {
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
          .login(
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
      title: 'Entrar',
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            if (_banner != null) AuthFormBanner(message: _banner!),
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
              enabled: !_submitting,
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _submitting
                    ? null
                    : () => context.go(AppRoutes.passwordReset),
                child: const Text('Esqueci minha senha'),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: _offline ? 'Tentar de novo' : 'Entrar',
                loading: _submitting,
                onPressed: _submit,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => context.go(AppRoutes.register),
              child: const Text('Criar conta'),
            ),
          ],
        ),
      ),
    );
  }
}
