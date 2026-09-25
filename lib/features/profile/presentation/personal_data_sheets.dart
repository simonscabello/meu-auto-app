import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/domain/profile_update.dart';
import 'package:meu_auto/features/auth/domain/user.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/profile/domain/profile_copy.dart';
import 'package:meu_auto/shared/widgets/app_bottom_sheet.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_date_picker.dart';
import 'package:meu_auto/shared/widgets/app_discard_guard.dart';
import 'package:meu_auto/shared/widgets/app_number_field.dart';
import 'package:meu_auto/shared/widgets/app_sheet_header.dart';

/// The three personal facts on Perfil, each changed in its own short sheet,
/// the way the name is ([NameEditSheet]): the row reads as a value, the
/// sheet is where it changes, and a 422 lands beside its field.
///
/// Each sheet resolves to true when something was saved or removed.
abstract final class PersonalDataSheets {
  static Future<bool> birthDate(BuildContext context, User user) async {
    final saved = await showAppSheet<bool>(
      context,
      isForm: true,
      builder: (_) => _BirthDateSheet(current: user.birthDate),
    );
    return saved ?? false;
  }

  static Future<bool> phone(BuildContext context, User user) async {
    final saved = await showAppSheet<bool>(
      context,
      isForm: true,
      builder: (_) => _PhoneSheet(current: user.phone),
    );
    return saved ?? false;
  }

  static Future<bool> cnh(BuildContext context, User user) async {
    final saved = await showAppSheet<bool>(
      context,
      isForm: true,
      builder: (_) => _CnhSheet(
        currentCategory: user.cnhCategory,
        currentExpiry: user.cnhExpiresOn,
      ),
    );
    return saved ?? false;
  }
}

/// What every one of these sheets does with a write: send it, close on
/// success, and put a 422 beside the field it names.
mixin _ProfileWrite<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool saving = false;
  String? banner;
  Map<String, String> fieldErrors = const {};

  List<String> get fields;

  Future<void> write(ProfileUpdate update) async {
    setState(() {
      saving = true;
      banner = null;
      fieldErrors = const {};
    });
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(update);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        saving = false;
        fieldErrors = ApiFormErrors.fieldsOf(failure);
        banner = ApiFormErrors.bannerOf(failure, shownFields: fields);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        saving = false;
        banner = 'Algo deu errado. Tente novamente.';
      });
    }
  }
}

/// "Remover" under the main button, only when there is something to remove.
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s8),
      child: AppButton(
        label: 'Remover',
        variant: AppButtonVariant.tertiary,
        onPressed: onPressed,
        expanded: true,
      ),
    );
  }
}

// ---------------------------------------------------------------- nascimento

class _BirthDateSheet extends ConsumerStatefulWidget {
  const _BirthDateSheet({required this.current});

  final CivilDate? current;

  @override
  ConsumerState<_BirthDateSheet> createState() => _BirthDateSheetState();
}

class _BirthDateSheetState extends ConsumerState<_BirthDateSheet>
    with _ProfileWrite {
  late final ValueNotifier<CivilDate?> _date = ValueNotifier(widget.current);

  @override
  List<String> get fields => const ['birth_date'];

  @override
  void dispose() {
    _date.dispose();
    super.dispose();
  }

  bool get _dirty => _date.value != null && _date.value != widget.current;

  Future<void> _pick() async {
    final picked = await pickBirthDate(context, initial: _date.value);
    if (picked == null) return;
    setState(() {
      _date.value = picked;
      fieldErrors = const {};
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppDiscardGuard(
      listenable: _date,
      isDirty: () => _dirty,
      busy: saving,
      child: AppSheetBody(
        children: [
          const AppSheetHeader(title: 'Data de nascimento'),
          const SizedBox(height: AppSpacing.s16),
          if (banner != null) AuthFormBanner(message: banner!),
          AppDateField(
            label: 'Data de nascimento',
            value: _date.value,
            enabled: !saving,
            onPick: _pick,
            errorText: fieldErrors['birth_date'],
          ),
          const SizedBox(height: AppSpacing.s24),
          AppButton(
            label: 'Salvar',
            loading: saving,
            onPressed: _dirty && !saving
                ? () => write(ProfileUpdate(birthDate: _date.value))
                : null,
            expanded: true,
          ),
          if (widget.current != null)
            _RemoveButton(
              onPressed: saving
                  ? null
                  : () => write(
                      const ProfileUpdate(clear: {ProfileField.birthDate}),
                    ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ telefone

class _PhoneSheet extends ConsumerStatefulWidget {
  const _PhoneSheet({required this.current});

  final String? current;

  @override
  ConsumerState<_PhoneSheet> createState() => _PhoneSheetState();
}

class _PhoneSheetState extends ConsumerState<_PhoneSheet> with _ProfileWrite {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current == null ? '' : formatPhone(widget.current!),
  );

  @override
  List<String> get fields => const ['phone'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _digits => digitsOnly(_controller.text);

  bool get _dirty => _digits.isNotEmpty && _digits != (widget.current ?? '');

  /// The server says why a number is wrong; this only stops a send that
  /// cannot be a phone with DDD.
  bool get _complete => _digits.length == 10 || _digits.length == 11;

  void _save() => write(ProfileUpdate(phone: _digits));

  @override
  Widget build(BuildContext context) {
    return AppDiscardGuard(
      listenable: _controller,
      isDirty: () => _dirty,
      busy: saving,
      child: AppSheetBody(
        children: [
          const AppSheetHeader(title: 'Telefone'),
          const SizedBox(height: AppSpacing.s16),
          if (banner != null) AuthFormBanner(message: banner!),
          TextField(
            controller: _controller,
            enabled: !saving,
            autofocus: true,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: const [PhoneInputFormatter()],
            onChanged: (_) => setState(() => fieldErrors = const {}),
            onSubmitted: (_) {
              if (_dirty && _complete && !saving) _save();
            },
            decoration: InputDecoration(
              labelText: 'Telefone com DDD',
              hintText: '(11) 91234-5678',
              errorText: fieldErrors['phone'],
            ),
          ),
          const SizedBox(height: AppSpacing.s24),
          AppButton(
            label: 'Salvar',
            loading: saving,
            onPressed: _dirty && _complete && !saving ? _save : null,
            expanded: true,
          ),
          if (widget.current != null)
            _RemoveButton(
              onPressed: saving
                  ? null
                  : () =>
                        write(const ProfileUpdate(clear: {ProfileField.phone})),
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------- CNH

class _CnhSheet extends ConsumerStatefulWidget {
  const _CnhSheet({required this.currentCategory, required this.currentExpiry});

  final CnhCategory? currentCategory;
  final CivilDate? currentExpiry;

  @override
  ConsumerState<_CnhSheet> createState() => _CnhSheetState();
}

class _CnhSheetState extends ConsumerState<_CnhSheet> with _ProfileWrite {
  late final ValueNotifier<(CnhCategory?, CivilDate?)> _value = ValueNotifier((
    widget.currentCategory,
    widget.currentExpiry,
  ));

  @override
  List<String> get fields => const ['cnh_category', 'cnh_expires_on'];

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  CnhCategory? get _category => _value.value.$1;
  CivilDate? get _expiry => _value.value.$2;

  bool get _dirty =>
      (_category != null && _category != widget.currentCategory) ||
      (_expiry != null && _expiry != widget.currentExpiry);

  bool get _hasAny =>
      widget.currentCategory != null || widget.currentExpiry != null;

  Future<void> _pickExpiry() async {
    // A CNH is renewed every ten years at most; an expired one is still a
    // fact worth recording, so the past stays open too.
    final picked = await pickCivilDate(
      context,
      initial: _expiry,
      yearsForward: 11,
    );
    if (picked == null) return;
    setState(() {
      _value.value = (_category, picked);
      fieldErrors = const {};
    });
  }

  void _save() {
    write(
      ProfileUpdate(
        cnhCategory: _category == widget.currentCategory ? null : _category,
        cnhExpiresOn: _expiry == widget.currentExpiry ? null : _expiry,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryError = fieldErrors['cnh_category'];
    return AppDiscardGuard(
      listenable: _value,
      isDirty: () => _dirty,
      busy: saving,
      child: AppSheetBody(
        children: [
          const AppSheetHeader(title: 'CNH'),
          const SizedBox(height: AppSpacing.s16),
          if (banner != null) AuthFormBanner(message: banner!),
          Text('Categoria', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              for (final category in CnhCategory.choosable)
                ChoiceChip(
                  label: Text(category.wire),
                  selected: _category == category,
                  onSelected: saving
                      ? null
                      : (_) => setState(() {
                          _value.value = (category, _expiry);
                          fieldErrors = const {};
                        }),
                ),
            ],
          ),
          if (categoryError != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(
              categoryError,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s20),
          AppDateField(
            label: 'Validade',
            value: _expiry,
            enabled: !saving,
            onPick: _pickExpiry,
            errorText: fieldErrors['cnh_expires_on'],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(ProfileCopy.cnhNote, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.s24),
          AppButton(
            label: 'Salvar',
            loading: saving,
            onPressed: _dirty && !saving ? _save : null,
            expanded: true,
          ),
          if (_hasAny)
            _RemoveButton(
              onPressed: saving
                  ? null
                  : () => write(
                      const ProfileUpdate(
                        clear: {
                          ProfileField.cnhCategory,
                          ProfileField.cnhExpiresOn,
                        },
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
