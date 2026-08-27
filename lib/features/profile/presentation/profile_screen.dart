import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/theme_mode_provider.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';
import 'package:meu_auto/features/auth/domain/user.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/profile/domain/profile_copy.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  User? _filledFor;
  bool _savingName = false;
  bool _loggingOut = false;
  bool _offline = false;
  String? _banner;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _fillName(User user) {
    if (_filledFor?.id == user.id && _filledFor?.name == user.name) {
      return;
    }
    _filledFor = user;
    if (_nameController.text != user.name) {
      _nameController.text = user.name;
    }
  }

  bool _nameDirty(User user) => _nameController.text.trim() != user.name;

  Future<void> _saveName() async {
    final previous = _filledFor?.name;
    setState(() {
      _savingName = true;
      _banner = null;
      _offline = false;
      _fieldErrors = {};
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateName(_nameController.text.trim());
      if (!mounted) {
        return;
      }
      setState(() => _savingName = false);
      showAppSnackBar(
        ScaffoldMessenger.of(context),
        message: 'Nome atualizado.',
        onUndo: previous == null
            ? null
            : () => unawaited(_restoreName(previous)),
      );
    } on ApiFailure catch (failure) {
      if (!mounted) {
        return;
      }
      setState(() {
        _savingName = false;
        _fieldErrors = ApiFormErrors.fieldsOf(failure);
        _banner = ApiFormErrors.bannerOf(failure);
        _offline = ApiFormErrors.isOffline(failure);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _savingName = false;
        _banner = 'Algo deu errado. Tente novamente.';
      });
    }
  }

  Future<void> _restoreName(String name) async {
    _nameController.text = name;
    setState(() {
      _savingName = true;
      _banner = null;
      _offline = false;
      _fieldErrors = {};
    });
    try {
      await ref.read(authControllerProvider.notifier).updateName(name);
      if (!mounted) {
        return;
      }
      setState(() => _savingName = false);
    } on ApiFailure catch (failure) {
      if (!mounted) {
        return;
      }
      setState(() {
        _savingName = false;
        _fieldErrors = ApiFormErrors.fieldsOf(failure);
        _banner = ApiFormErrors.bannerOf(failure);
        _offline = ApiFormErrors.isOffline(failure);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _savingName = false;
        _banner = 'Algo deu errado. Tente novamente.';
      });
    }
  }

  Future<void> _logout() async {
    if (!await confirmLogout(context) || !mounted) {
      return;
    }
    setState(() => _loggingOut = true);
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.system;

    return AppScaffold(
      title: 'Perfil',
      body: auth.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.s24),
          child: AppSkeletonList(),
        ),
        error: (error, _) => AppErrorState.fromError(
          error: error,
          onRetry: () => ref.invalidate(authControllerProvider),
        ),
        data: (status) {
          if (status is! AuthLoggedIn) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.s24),
              child: AppSkeletonList(),
            );
          }
          _fillName(status.user);
          return ProfileContent(
            user: status.user,
            nameController: _nameController,
            nameError: _fieldErrors['name'],
            banner: _banner,
            savingName: _savingName,
            nameDirty: _nameDirty(status.user),
            loggingOut: _loggingOut,
            offline: _offline,
            themeMode: themeMode,
            onSaveName: _saveName,
            onNameChanged: () => setState(() {
              if (_fieldErrors.containsKey('name')) {
                _fieldErrors.remove('name');
              }
            }),
            onThemeMode: (mode) {
              unawaited(ref.read(themeModeProvider.notifier).setMode(mode));
            },
            onVehicles: () => context.push(AppRoutes.vehicles),
            onLogout: _logout,
            onDeleteAccount: () => context.push(AppRoutes.deleteAccount),
          );
        },
      ),
    );
  }
}

class ProfileContent extends StatelessWidget {
  const ProfileContent({
    super.key,
    required this.user,
    required this.nameController,
    required this.nameError,
    required this.banner,
    required this.savingName,
    required this.nameDirty,
    required this.loggingOut,
    required this.themeMode,
    required this.onSaveName,
    required this.onNameChanged,
    required this.onThemeMode,
    required this.onVehicles,
    required this.onLogout,
    required this.onDeleteAccount,
    this.offline = false,
  });

  final User user;
  final TextEditingController nameController;
  final String? nameError;
  final String? banner;
  final bool savingName;
  final bool nameDirty;
  final bool loggingOut;
  final bool offline;
  final ThemeMode themeMode;
  final VoidCallback onSaveName;
  final VoidCallback onNameChanged;
  final ValueChanged<ThemeMode> onThemeMode;
  final VoidCallback onVehicles;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = savingName || loggingOut;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (banner != null) AuthFormBanner(message: banner!),
        TextField(
          controller: nameController,
          enabled: !busy,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.name],
          inputFormatters: [LengthLimitingTextInputFormatter(120)],
          onChanged: (_) => onNameChanged(),
          onSubmitted: (_) {
            if (nameDirty && !busy) {
              onSaveName();
            }
          },
          decoration: InputDecoration(
            labelText: 'Nome',
            errorText: nameError,
            errorMaxLines: 3,
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: offline ? 'Tentar de novo' : 'Salvar nome',
            loading: savingName,
            onPressed: nameDirty && !loggingOut ? onSaveName : null,
          ),
        ),
        const SizedBox(height: AppSpacing.s24),
        Text('E-mail', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.s8),
        Text(user.email, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.s8),
        Text(
          ProfileCopy.emailExplanation,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.s24),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.directions_car_outlined),
          title: const Text('Meus veículos'),
          trailing: const Icon(Icons.chevron_right),
          onTap: busy ? null : onVehicles,
        ),
        const SizedBox(height: AppSpacing.s16),
        const AppSectionHeader(title: 'Aparência'),
        RadioGroup<ThemeMode>(
          groupValue: themeMode,
          onChanged: (mode) {
            if (mode == null || busy) {
              return;
            }
            onThemeMode(mode);
          },
          child: Column(
            children: [
              RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                title: const Text('Claro'),
                contentPadding: EdgeInsets.zero,
                enabled: !busy,
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                title: const Text('Escuro'),
                contentPadding: EdgeInsets.zero,
                enabled: !busy,
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                title: const Text('Seguir o sistema'),
                contentPadding: EdgeInsets.zero,
                enabled: !busy,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            label: 'Sair',
            variant: AppButtonVariant.secondary,
            loading: loggingOut,
            onPressed: savingName ? null : onLogout,
          ),
        ),
        const SizedBox(height: AppSpacing.s40),
        Divider(color: theme.colorScheme.outlineVariant),
        const SizedBox(height: AppSpacing.s16),
        AppButton(
          label: 'Excluir minha conta',
          variant: AppButtonVariant.tertiary,
          foregroundColor: theme.colorScheme.error,
          onPressed: busy ? null : onDeleteAccount,
        ),
      ],
    );
  }
}
