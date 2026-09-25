import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/auth/presentation/auth_password_field.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_form_section.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmation = TextEditingController();

  bool _submitting = false;
  bool _offline = false;
  String? _banner;
  String? _confirmationError;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _currentPassword.text.isNotEmpty &&
      _newPassword.text.length >= 8 &&
      _confirmation.text.length >= 8 &&
      !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;

    if (_newPassword.text == _currentPassword.text) {
      setState(() {
        _fieldErrors = {
          'new_password': 'A nova senha deve ser diferente da atual.',
        };
        _confirmationError = null;
      });
      return;
    }
    if (_newPassword.text != _confirmation.text) {
      setState(() {
        _confirmationError = 'As senhas não conferem.';
        _fieldErrors = {};
      });
      return;
    }

    setState(() {
      _submitting = true;
      _offline = false;
      _banner = null;
      _confirmationError = null;
      _fieldErrors = {};
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .changePassword(
            currentPassword: _currentPassword.text,
            newPassword: _newPassword.text,
          );
      if (!mounted) return;
      context.pop(true);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _fieldErrors = ApiFormErrors.fieldsOf(failure);
        _banner = ApiFormErrors.bannerOf(failure);
        _offline = ApiFormErrors.isOffline(failure);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _banner = 'Algo deu errado. Tente novamente.';
      });
    }
  }

  void _fieldChanged(String field) {
    setState(() {
      _fieldErrors.remove(field);
      if (field == 'new_password') {
        _confirmationError = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      child: AppScaffold(
        title: 'Alterar senha',
        body: ChangePasswordContent(
          currentPasswordController: _currentPassword,
          newPasswordController: _newPassword,
          confirmationController: _confirmation,
          currentPasswordError: _fieldErrors['current_password'],
          newPasswordError: _fieldErrors['new_password'],
          confirmationError: _confirmationError,
          banner: _banner,
          submitting: _submitting,
          canSubmit: _canSubmit,
          offline: _offline,
          onCurrentPasswordChanged: () => _fieldChanged('current_password'),
          onNewPasswordChanged: () => _fieldChanged('new_password'),
          onConfirmationChanged: () => setState(() {
            _confirmationError = null;
          }),
          onSubmit: _submit,
        ),
      ),
    );
  }
}

class ChangePasswordContent extends StatelessWidget {
  const ChangePasswordContent({
    super.key,
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmationController,
    required this.currentPasswordError,
    required this.newPasswordError,
    required this.confirmationError,
    required this.banner,
    required this.submitting,
    required this.canSubmit,
    required this.onCurrentPasswordChanged,
    required this.onNewPasswordChanged,
    required this.onConfirmationChanged,
    required this.onSubmit,
    this.offline = false,
  });

  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmationController;
  final String? currentPasswordError;
  final String? newPasswordError;
  final String? confirmationError;
  final String? banner;
  final bool submitting;
  final bool canSubmit;
  final bool offline;
  final VoidCallback onCurrentPasswordChanged;
  final VoidCallback onNewPasswordChanged;
  final VoidCallback onConfirmationChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The current password, then — a block apart — the new one twice. The
    // space says which fields belong together; a label over each part would
    // only repeat the field's own label. The button stays above the keyboard.
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: AppSpacing.screenHeaded,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Text(
                  'Os outros aparelhos saem da conta. Este continua conectado.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.s24),
                if (banner != null) AuthFormBanner(message: banner!),
                AuthPasswordField(
                  controller: currentPasswordController,
                  label: 'Senha atual',
                  enabled: !submitting,
                  errorText: currentPasswordError,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => onCurrentPasswordChanged(),
                ),
                const AppFormGap(),
                AuthPasswordField(
                  controller: newPasswordController,
                  label: 'Nova senha',
                  hint: newPasswordHint,
                  enabled: !submitting,
                  autofillHints: const [AutofillHints.newPassword],
                  errorText: newPasswordError,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => onNewPasswordChanged(),
                ),
                const SizedBox(height: AppSpacing.s12),
                AuthPasswordField(
                  controller: confirmationController,
                  label: 'Confirmar nova senha',
                  enabled: !submitting,
                  autofillHints: const [AutofillHints.newPassword],
                  errorText: confirmationError,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSubmit(),
                  onChanged: (_) => onConfirmationChanged(),
                ),
              ],
            ),
          ),
          AppFormFooter(
            child: AppButton(
              label: offline ? 'Tentar de novo' : 'Alterar senha',
              loading: submitting,
              onPressed: canSubmit && !submitting ? onSubmit : null,
              expanded: true,
            ),
          ),
        ],
      ),
    );
  }
}
