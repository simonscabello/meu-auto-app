import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/features/profile/domain/profile_copy.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/theme_mode_provider.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';
import 'package:meu_auto/features/auth/domain/user.dart';
import 'package:meu_auto/features/profile/presentation/name_edit_sheet.dart';
import 'package:meu_auto/features/profile/presentation/personal_data_sheets.dart';
import 'package:meu_auto/features/profile/presentation/photo_source_sheet.dart';
import 'package:meu_auto/shared/widgets/app_avatar.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
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
  bool _photoBusy = false;

  /// Take, pick or remove the photo. The picker shrinks it to 1024px before
  /// it leaves the phone, so an upload is a few hundred KB, not a 12 MP shot.
  Future<void> _changePhoto(User user) async {
    final action = await PhotoSourceSheet.show(
      context,
      hasPhoto: user.photoUrl != null,
    );
    if (action == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final auth = ref.read(authControllerProvider.notifier);

    if (action == PhotoAction.remove) {
      final confirmed = await confirmAction(
        context,
        title: 'Remover a foto?',
        message: 'O perfil volta a mostrar a sua inicial.',
        confirmLabel: 'Remover',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
      await _photoWrite(messenger, ProfileCopy.photoRemoved, auth.removePhoto);
      return;
    }

    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: action == PhotoAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } on Object {
      if (!mounted) return;
      showAppErrorSnackBar(
        messenger,
        message: action == PhotoAction.camera
            ? 'Não foi possível abrir a câmera.'
            : 'Não foi possível abrir a galeria.',
      );
      return;
    }
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    await _photoWrite(
      messenger,
      ProfileCopy.photoSaved,
      () => auth.setPhoto(
        bytes: bytes,
        filename: file!.name,
        contentType: file.mimeType,
      ),
    );
  }

  Future<void> _photoWrite(
    ScaffoldMessengerState messenger,
    String done,
    Future<void> Function() write,
  ) async {
    setState(() => _photoBusy = true);
    try {
      await write();
      if (!mounted) return;
      showAppSnackBar(messenger, message: done);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      final field = failure.fields['photo'];
      showAppErrorSnackBar(messenger, message: field ?? failure.message);
    } catch (_) {
      if (!mounted) return;
      showAppErrorSnackBar(
        messenger,
        message: 'Algo deu errado. Tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _editPersonal(
    Future<bool> Function(BuildContext, User) open,
    User user,
  ) async {
    final saved = await open(context, user);
    if (!saved || !mounted) return;
    showAppSnackBar(
      ScaffoldMessenger.of(context),
      message: ProfileCopy.personalSaved,
    );
  }

  /// Opens the name sheet, and owns what happens after it closes.
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
      showAppSnackBar(ScaffoldMessenger.of(context), message: failure.message);
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

  Future<void> _changePassword() async {
    final changed = await context.push<bool>(AppRoutes.changePassword);
    if (changed != true || !mounted) return;
    showAppSnackBar(
      ScaffoldMessenger.of(context),
      message: 'Senha alterada. Os outros aparelhos foram desconectados.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.dark;

    return AppScaffold(
      title: 'Perfil',
      body: auth.when(
        loading: () =>
            const Padding(padding: AppSpacing.screen, child: AppSkeletonList()),
        error: (error, _) => AppErrorState.fromError(
          error: error,
          onRetry: () => ref.invalidate(authControllerProvider),
        ),
        data: (status) {
          if (status is! AuthLoggedIn) {
            return const Padding(
              padding: AppSpacing.screen,
              child: AppSkeletonList(),
            );
          }
          return ProfileContent(
            user: status.user,
            themeMode: themeMode,
            loggingOut: _loggingOut,
            photoBusy: _photoBusy,
            onEditPhoto: () => unawaited(_changePhoto(status.user)),
            onEditName: () => unawaited(_editName(status.user)),
            onBirthDate: () => unawaited(
              _editPersonal(PersonalDataSheets.birthDate, status.user),
            ),
            onPhone: () =>
                unawaited(_editPersonal(PersonalDataSheets.phone, status.user)),
            onCnh: () =>
                unawaited(_editPersonal(PersonalDataSheets.cnh, status.user)),
            onThemeMode: (mode) {
              unawaited(ref.read(themeModeProvider.notifier).setMode(mode));
            },
            onVehicles: () => context.push(AppRoutes.vehicles),
            onChangePassword: () => unawaited(_changePassword()),
            onLogout: _logout,
            onDeleteAccount: () => context.push(AppRoutes.deleteAccount),
          );
        },
      ),
    );
  }
}

/// Under the account group: why the e-mail, shown in the header, has no row
/// of its own to tap.

/// Perfil: who is signed in, then a list of what is set and a way to change
/// each thing, grouped, with the exits kept apart and last.
///
/// The header is the person — the initial, the name, the e-mail — set as
/// type on the page, not in a card: it is not a setting and nothing in it is
/// tapped. Nothing here is invented. There is no version row and no privacy
/// link because the app has neither yet — a settings screen that lies about
/// what it can do is worse than a short one.
class ProfileContent extends StatelessWidget {
  const ProfileContent({
    super.key,
    required this.user,
    required this.themeMode,
    required this.onEditName,
    this.onEditPhoto,
    this.onBirthDate,
    this.onPhone,
    this.onCnh,
    this.photoBusy = false,
    required this.onThemeMode,
    required this.onVehicles,
    required this.onChangePassword,
    required this.onLogout,
    required this.onDeleteAccount,
    this.loggingOut = false,
  });

  final User user;
  final ThemeMode themeMode;
  final bool loggingOut;
  final VoidCallback onEditName;
  final VoidCallback? onEditPhoto;
  final VoidCallback? onBirthDate;
  final VoidCallback? onPhone;
  final VoidCallback? onCnh;

  /// A photo is being sent or removed: the avatar shows it and cannot be
  /// tapped again until it is done.
  final bool photoBusy;
  final ValueChanged<ThemeMode> onThemeMode;
  final VoidCallback onVehicles;
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.screenHeaded,
      children: [
        _ProfileHeader(
          user: user,
          busy: photoBusy,
          onEditPhoto: loggingOut ? null : onEditPhoto,
        ),
        const SizedBox(height: AppSpacing.s32),
        AppGroup(
          title: 'Conta',
          footnote: ProfileCopy.emailNote,
          children: [
            AppSettingRow(
              label: 'Nome',
              icon: Icons.person_outline,
              value: user.name,
              onTap: loggingOut ? null : onEditName,
            ),
            AppSettingRow(
              label: 'Alterar senha',
              icon: Icons.lock_outline,
              onTap: loggingOut ? null : onChangePassword,
            ),
          ],
        ),
        const SizedBox(height: appGroupGap),
        AppGroup(
          title: 'Dados pessoais',
          footnote: ProfileCopy.personalNote,
          children: [
            AppSettingRow(
              label: 'Data de nascimento',
              icon: Icons.cake_outlined,
              value: user.birthDate == null
                  ? ProfileCopy.notInformed
                  : formatCivilDate(user.birthDate!),
              onTap: loggingOut ? null : onBirthDate,
            ),
            AppSettingRow(
              label: 'Telefone',
              icon: Icons.phone_outlined,
              value: user.phone == null
                  ? ProfileCopy.notInformed
                  : formatPhone(user.phone!),
              onTap: loggingOut ? null : onPhone,
            ),
            AppSettingRow(
              label: 'CNH',
              icon: Icons.badge_outlined,
              value: cnhSummary(user) ?? ProfileCopy.notInformed,
              onTap: loggingOut ? null : onCnh,
            ),
          ],
        ),
        const SizedBox(height: appGroupGap),
        AppGroup(
          title: 'Veículos',
          children: [
            AppSettingRow(
              label: 'Meus veículos',
              icon: Icons.directions_car_outlined,
              onTap: loggingOut ? null : onVehicles,
            ),
          ],
        ),
        const SizedBox(height: appGroupGap),
        // The segmented control is its own surface; a card around it would
        // be a box in a box.
        const AppSectionHeader(
          title: 'Aparência',
          subtitle: 'Vale só neste aparelho.',
        ),
        AppSegmented<ThemeMode>(
          value: themeMode,
          enabled: !loggingOut,
          onChanged: onThemeMode,
          options: const [
            AppSegmentedOption(value: ThemeMode.dark, label: 'Escuro'),
            AppSegmentedOption(value: ThemeMode.light, label: 'Claro'),
            AppSegmentedOption(value: ThemeMode.system, label: 'Sistema'),
          ],
        ),
        const SizedBox(height: AppSpacing.s40),
        // Kept apart, untitled, and last. Signing out and deleting an account
        // are not settings; they are exits, and they must not sit a thumb's
        // width from the theme picker. "Sair" goes nowhere, so it carries no
        // chevron; the red is only on the words and the glyph.
        AppGroup(
          children: [
            AppSettingRow(
              label: 'Sair',
              icon: Icons.logout_outlined,
              onTap: loggingOut ? null : onLogout,
              trailing: loggingOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const SizedBox.shrink(),
            ),
            AppSettingRow(
              label: 'Excluir minha conta',
              icon: Icons.delete_outline,
              destructive: true,
              onTap: loggingOut ? null : onDeleteAccount,
            ),
          ],
        ),
      ],
    );
  }
}

/// "AB · até 30/06/2031", as short as the row allows; null when nothing is
/// informed.
@visibleForTesting
String? cnhSummary(User user) {
  final category = user.cnhCategory;
  final expiry = user.cnhExpiresOn;
  if (category == null && expiry == null) return null;
  return joinParts([
    if (category != null && category != CnhCategory.desconhecido) category.wire,
    if (expiry != null) 'até ${formatCivilDate(expiry)}',
  ]);
}

/// Who is signed in: the photo or the initial, large, the name, the e-mail.
///
/// The same disc as the account button on every tab, grown, so the screen
/// visibly is the place that button opens. Tapping it changes the photo; the
/// small camera badge is what says so.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    this.busy = false,
    this.onEditPhoto,
  });

  final User user;
  final bool busy;
  final VoidCallback? onEditPhoto;

  static const double _avatar = 64;
  static const double _badge = 24;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = user.name.trim();
    final hasPhoto = user.photoUrl != null;

    final avatar = SizedBox.square(
      dimension: _avatar,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AppAvatar(name: name, photoUrl: user.photoUrl, size: _avatar),
          if (busy)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surface.withValues(alpha: 0.6),
                ),
                child: const Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
            )
          else if (onEditPhoto != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: _badge,
                height: _badge,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: 13,
                  color: scheme.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );

    return Row(
      children: [
        Semantics(
          container: true,
          button: onEditPhoto != null,
          label: hasPhoto
              ? 'Alterar foto do perfil'
              : 'Adicionar foto do perfil',
          excludeSemantics: true,
          onTap: busy ? null : onEditPhoto,
          child: GestureDetector(
            onTap: busy ? null : onEditPhoto,
            child: avatar,
          ),
        ),
        const SizedBox(width: AppSpacing.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                container: true,
                header: true,
                child: Text(name, style: theme.textTheme.headlineSmall),
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
