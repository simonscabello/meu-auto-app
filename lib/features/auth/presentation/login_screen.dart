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
import 'package:meu_auto/features/auth/data/device_biometrics.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';
import 'package:meu_auto/features/auth/domain/biometric_copy.dart';
import 'package:meu_auto/features/auth/domain/user.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/auth/presentation/auth_password_field.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';
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
  bool _unlocking = false;
  bool _offline = false;
  String? _banner;
  Map<String, String> _fieldErrors = {};

  bool get _busy => _submitting || _unlocking;

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
    ref.read(loginProblemProvider.notifier).state = null;
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
            beforeEntering: _beforeEntering,
          );
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

  /// The password was right and the app is about to move on: the last
  /// moment this screen is still here to ask anything.
  Future<void> _beforeEntering(User user) async {
    // Saving the password comes first. It is what the phone's password
    // manager waits for, and a refused sign-in never gets here, so a wrong
    // password is never offered to be saved.
    TextInput.finishAutofillContext();

    final auth = ref.read(authControllerProvider.notifier);
    if (!await auth.shouldOfferBiometrics(user) || !mounted) {
      return;
    }
    // Asked once per account, whatever the answer.
    await auth.markBiometricsOffered(user);
    if (!mounted) {
      return;
    }
    // The root messenger: the app will be on another screen when it shows.
    final messenger = ScaffoldMessenger.of(context);
    final accepted = await confirmAction(
      context,
      title: BiometricCopy.offerTitle,
      message: BiometricCopy.offerMessage,
      confirmLabel: BiometricCopy.offerAccept,
      cancelLabel: BiometricCopy.offerDecline,
    );
    if (!accepted) {
      return;
    }
    final check = await auth.enableBiometrics(user);
    if (check != BiometricCheck.confirmed) {
      showAppErrorSnackBar(messenger, message: BiometricCopy.notConfirmedLater);
    }
  }

  /// Only while a stored session is locked: whoever chose the password on
  /// the unlock screen can still change their mind here.
  Future<void> _unlock() async {
    ref.read(loginProblemProvider.notifier).state = null;
    setState(() {
      _unlocking = true;
      _banner = null;
      _offline = false;
    });
    final result = await ref.read(authControllerProvider.notifier).unlock();
    if (!mounted || result == UnlockResult.unlocked) {
      return;
    }
    setState(() {
      _unlocking = false;
      _banner = switch (result) {
        UnlockResult.lockedOut => BiometricCopy.lockedOut,
        UnlockResult.unreachable => BiometricCopy.unreachable,
        UnlockResult.expired => BiometricCopy.expired,
        UnlockResult.notConfirmed || UnlockResult.unlocked => null,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final banner = _banner ?? ref.watch(loginProblemProvider);
    // The biometric is offered here only for a session that is waiting
    // behind it; on a phone signed out, there is nothing for it to open.
    final locked = ref.watch(authControllerProvider).valueOrNull is AuthLocked;
    final canUnlock =
        locked && (ref.watch(biometricsAvailableProvider).valueOrNull ?? false);
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
                    if (banner != null) AuthFormBanner(message: banner),
                    TextField(
                      controller: _emailController,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      // `username` beside `email`: password managers pair a
                      // saved password with the field marked as the username.
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
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
                      enabled: !_busy,
                      errorText: _fieldErrors['password'],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!_busy) {
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
                          onPressed: _busy
                              ? null
                              : () => context.go(AppRoutes.passwordReset),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    AppButton(
                      label: _offline ? 'Tentar de novo' : 'Entrar',
                      loading: _submitting,
                      onPressed: _unlocking ? null : _submit,
                      expanded: true,
                    ),
                    if (canUnlock) ...[
                      const SizedBox(height: AppSpacing.s12),
                      AppButton(
                        label: BiometricCopy.unlockButton,
                        icon: Icons.fingerprint,
                        variant: AppButtonVariant.secondary,
                        loading: _unlocking,
                        onPressed: _submitting ? null : _unlock,
                        expanded: true,
                      ),
                    ],
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
                          onPressed: _busy
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
