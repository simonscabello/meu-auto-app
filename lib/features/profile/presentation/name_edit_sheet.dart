import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/shared/widgets/app_bottom_sheet.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_sheet_header.dart';

/// Where the name is actually changed.
///
/// The setting on Perfil reads as a value; changing it is a deliberate act
/// that opens here. The write lives in the sheet because the field-level 422
/// belongs beside the field. The screen behind keeps the confirmation and the
/// undo, because by then this sheet is gone.
class NameEditSheet extends ConsumerStatefulWidget {
  const NameEditSheet({super.key, required this.currentName});

  final String currentName;

  /// Resolves to the saved name, or null when nothing was changed.
  static Future<String?> show(BuildContext context, String currentName) {
    return showAppSheet<String>(
      context,
      builder: (sheetContext) => NameEditSheet(currentName: currentName),
    );
  }

  @override
  ConsumerState<NameEditSheet> createState() => _NameEditSheetState();
}

class _NameEditSheetState extends ConsumerState<NameEditSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.currentName,
  );
  bool _saving = false;
  String? _banner;
  String? _fieldError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _dirty => _controller.text.trim() != widget.currentName;

  Future<void> _save() async {
    final name = _controller.text.trim();
    setState(() {
      _saving = true;
      _banner = null;
      _fieldError = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).updateName(name);
      if (!mounted) return;
      Navigator.pop(context, name);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _fieldError = ApiFormErrors.fieldsOf(failure)['name'];
        _banner = ApiFormErrors.bannerOf(failure, shownFields: const ['name']);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _banner = 'Algo deu errado. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetBody(
      children: [
        const AppSheetHeader(title: 'Seu nome', closable: false),
        const SizedBox(height: AppSpacing.s16),
        if (_banner != null) AuthFormBanner(message: _banner!),
        TextField(
          controller: _controller,
          enabled: !_saving,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.name],
          inputFormatters: [LengthLimitingTextInputFormatter(120)],
          onChanged: (_) => setState(() => _fieldError = null),
          onSubmitted: (_) {
            if (_dirty && !_saving) _save();
          },
          decoration: InputDecoration(
            labelText: 'Nome',
            errorText: _fieldError,
          ),
        ),
        const SizedBox(height: AppSpacing.s24),
        AppButton(
          label: 'Salvar',
          loading: _saving,
          onPressed: _dirty && !_saving ? _save : null,
          expanded: true,
        ),
      ],
    );
  }
}
