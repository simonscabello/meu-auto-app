import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/theme_mode_provider.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';
import 'package:meu_auto/features/auth/domain/user.dart';
import 'package:meu_auto/features/profile/domain/profile_copy.dart';
import 'package:meu_auto/features/profile/presentation/name_edit_sheet.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_segmented.dart';
import 'package:meu_auto/shared/widgets/app_setting_row.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _loggingOut = false;

  /// Opens the name sheet, and owns what happens after it closes.
  ///
  /// The confirmation and the undo live here rather than in the sheet because
  /// by the time either is worth showing, the sheet has been dismissed.
  Future<void> _editName(User user) async {
    final saved = await NameEditSheet.show(context, user.name);
    if (saved == null || !mounted) return;
    showAppSnackBar(
      ScaffoldMessenger.of(context),
      message: 'Nome atualizado.',
      onUndo: () => unawaited(_restoreName(user.name)),
    );
  }

  Future<void> _restoreName(String name) async {
    try {
      await ref.read(authControllerProvider.notifier).updateName(name);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      showAppSnackBar(
        ScaffoldMessenger.of(context),
        message: failure.message,
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        ScaffoldMessenger.of(context),
        message: 'Algo deu errado. Tente novamente.',
      );
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
          return ProfileContent(
            user: status.user,
            themeMode: themeMode,
            loggingOut: _loggingOut,
            onEditName: () => unawaited(_editName(status.user)),
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

/// Perfil as a settings screen, which is what it always was.
///
/// It used to open with a text field and a "Salvar nome" button that were on
/// screen whether or not anyone wanted to rename themselves, followed by
/// three loose radio tiles and a full-width "Sair" in the middle of the page.
/// A settings screen is a list of what is set and a way to change each thing,
/// grouped, with the dangerous rows kept apart from the ordinary ones.
///
/// Nothing here is invented. There is no version row and no privacy link
/// because the app has neither yet — a settings screen that lies about what
/// it can do is worse than a short one. The sections are laid out so both
/// drop in without moving anything else.
class ProfileContent extends StatelessWidget {
  const ProfileContent({
    super.key,
    required this.user,
    required this.themeMode,
    required this.onEditName,
    required this.onThemeMode,
    required this.onVehicles,
    required this.onLogout,
    required this.onDeleteAccount,
    this.loggingOut = false,
  });

  final User user;
  final ThemeMode themeMode;
  final bool loggingOut;
  final VoidCallback onEditName;
  final ValueChanged<ThemeMode> onThemeMode;
  final VoidCallback onVehicles;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s16,
        AppSpacing.s32,
      ),
      children: [
        const AppSectionHeader(title: 'Conta'),
        AppSettingRow(
          label: 'Nome',
          value: user.name,
          onTap: loggingOut ? null : onEditName,
        ),
        const AppRowDivider(indent: 0),
        AppSettingRow(label: 'E-mail', value: user.email),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s4),
          child: Text(
            ProfileCopy.emailExplanation,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s24),
        const AppSectionHeader(title: 'Veículos'),
        AppSettingRow(
          label: 'Meus veículos',
          icon: Icons.directions_car_outlined,
          onTap: loggingOut ? null : onVehicles,
        ),
        const SizedBox(height: AppSpacing.s24),
        const AppSectionHeader(title: 'Aparência'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
          child: Row(
            children: [
              Expanded(
                child: Text('Tema', style: theme.textTheme.bodyLarge),
              ),
              const SizedBox(width: AppSpacing.s16),
              // Constrained rather than Expanded: at a large text scale the
              // three labels need room, but the control must never grow wide
              // enough to push the label off a 360dp screen.
              SizedBox(
                width: 210,
                child: AppSegmented<ThemeMode>(
                  value: themeMode,
                  enabled: !loggingOut,
                  onChanged: onThemeMode,
                  options: const [
                    AppSegmentedOption(
                      value: ThemeMode.light,
                      label: 'Claro',
                    ),
                    AppSegmentedOption(
                      value: ThemeMode.dark,
                      label: 'Escuro',
                    ),
                    AppSegmentedOption(
                      value: ThemeMode.system,
                      label: 'Sistema',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s32),
        // Kept apart, and last. Signing out and deleting an account are not
        // settings; they are exits, and they must not sit a thumb's width
        // from the theme picker.
        const AppSectionHeader(title: 'Sessão'),
        AppSettingRow(
          label: 'Sair',
          icon: Icons.logout,
          onTap: onLogout,
          trailing: loggingOut
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
        const AppRowDivider(indent: 0),
        AppSettingRow(
          label: 'Excluir minha conta',
          icon: Icons.delete_outline,
          destructive: true,
          onTap: loggingOut ? null : onDeleteAccount,
        ),
      ],
    );
  }
}
