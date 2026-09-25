import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/application/login_notice.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/auth/presentation/auth_password_field.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';
import 'package:meu_auto/shared/widgets/app_wordmark.dart';

/// What the app keeps, in the owner's words. Three of the things it actually
/// does, and nothing it does not.
const loginTagline = 'Manutenção, abastecimento e documentos do seu carro.';

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
      showAppSnackBar(ScaffoldMessenger.of(context), message: notice);
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
    final theme = Theme.of(context);
    // No app bar. This is the front door, and an app bar reading "Entrar"
    // above a button reading "Entrar" is chrome saying the same word twice.
    // The mark is the heading; the form follows it; the way to a new account
    // waits at the foot of the page, apart from the sign-in it is not.
    return AppScaffold(
      body: AutofillGroup(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.s48,
                  AppSpacing.page,
                  AppSpacing.s16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      container: true,
                      header: true,
                      child: const AppWordmark(size: AppWordmarkSize.large),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      loginTagline,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s40),
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
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
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
                      // Pulled into the gutter by the button's own padding,
                      // so the words end where the field above them ends.
                      child: Transform.translate(
                        offset: const Offset(AppSpacing.s12, 0),
                        child: AppButton(
                          label: 'Esqueci minha senha',
                          variant: AppButtonVariant.tertiary,
                          onPressed: _submitting
                              ? null
                              : () => context.go(AppRoutes.passwordReset),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    AppButton(
                      label: _offline ? 'Tentar de novo' : 'Entrar',
                      loading: _submitting,
                      onPressed: _submit,
                      expanded: true,
                    ),
                    const Spacer(),
                    const SizedBox(height: AppSpacing.s32),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Ainda não tem conta?',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        AppButton(
                          label: 'Criar conta',
                          variant: AppButtonVariant.tertiary,
                          onPressed: _submitting
                              ? null
                              : () => context.go(AppRoutes.register),
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
    );
  }
}
