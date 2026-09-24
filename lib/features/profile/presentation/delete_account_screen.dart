import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/application/login_notice.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/auth/presentation/auth_password_field.dart';
import 'package:meu_auto/features/profile/domain/delete_account_copy.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _passwordController = TextEditingController();
  bool _submitting = false;
  bool _offline = false;
  String? _banner;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  bool get _hasPassword => _passwordController.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_hasPassword || _submitting) {
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
          .read(authControllerProvider.notifier)
          .deleteAccount(password: _passwordController.text);
      ref.read(loginNoticeProvider.notifier).state = DeleteAccountCopy.done;
      await ref.read(authControllerProvider.notifier).clearLocalSession();
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
    return PopScope(
      canPop: !_submitting,
      child: AppScaffold(
        title: 'Excluir minha conta',
        body: DeleteAccountContent(
          passwordController: _passwordController,
          passwordError: _fieldErrors['password'],
          banner: _banner,
          submitting: _submitting,
          hasPassword: _hasPassword,
          offline: _offline,
          onPasswordChanged: () => setState(() {
            if (_fieldErrors.containsKey('password')) {
              _fieldErrors.remove('password');
            }
          }),
          onSubmit: _submit,
        ),
      ),
    );
  }
}

class DeleteAccountContent extends StatelessWidget {
  const DeleteAccountContent({
    super.key,
    required this.passwordController,
    required this.passwordError,
    required this.banner,
    required this.submitting,
    required this.hasPassword,
    required this.onPasswordChanged,
    required this.onSubmit,
    this.offline = false,
  });

  final TextEditingController passwordController;
  final String? passwordError;
  final String? banner;
  final bool submitting;
  final bool hasPassword;
  final bool offline;
  final VoidCallback onPasswordChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: AppSpacing.screenHeaded,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppIconWell(
                icon: Icons.delete_outline,
                size: AppIconWellSize.l,
                tone: AppIconWellTone.status,
                status: AppStatus.vencido,
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Text(
                  DeleteAccountCopy.irreversible,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: appGroupGap),
        AppGroup(
          title: 'O que será apagado',
          dividerIndent: 0,
          children: [
            for (final item in DeleteAccountCopy.whatIsErased)
              AppListRowShell(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(
                        Icons.remove,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Text(item, style: theme.textTheme.bodyLarge),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: appGroupGap),
        if (banner != null) AuthFormBanner(message: banner!),
        AuthPasswordField(
          controller: passwordController,
          label: 'Senha atual',
          enabled: !submitting,
          errorText: passwordError,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          onChanged: (_) => onPasswordChanged(),
        ),
        const SizedBox(height: AppSpacing.s24),
        AppButton(
          label: offline ? 'Tentar de novo' : 'Excluir minha conta',
          variant: AppButtonVariant.destructive,
          loading: submitting,
          onPressed: hasPassword && !submitting ? onSubmit : null,
          expanded: true,
        ),
      ],
    );
  }
}
