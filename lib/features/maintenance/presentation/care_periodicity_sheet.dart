import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_item_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/features/maintenance/domain/care_periodicity.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/plan_copy.dart';
import 'package:meu_auto/shared/widgets/app_bottom_sheet.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_choice_row.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_sheet_header.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

class CarePeriodicitySheet extends ConsumerStatefulWidget {
  const CarePeriodicitySheet({
    super.key,
    required this.vehicleId,
    required this.plan,
    this.defaultIntervalDays,
  });

  final String vehicleId;
  final MaintenancePlan plan;
  final int? defaultIntervalDays;

  static Future<void> show(
    BuildContext context, {
    required String vehicleId,
    required MaintenancePlan plan,
  }) {
    return showAppSheet<void>(
      context,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final items = ref.watch(maintenanceItemsProvider).asData?.value;
          int? recommended;
          if (items != null) {
            for (final item in items) {
              if (item.id != plan.maintenanceItemId) continue;
              recommended = item.defaultIntervalDays;
              break;
            }
          }
          return CarePeriodicitySheet(
            vehicleId: vehicleId,
            plan: plan,
            defaultIntervalDays: recommended,
          );
        },
      ),
    );
  }

  @override
  ConsumerState<CarePeriodicitySheet> createState() =>
      _CarePeriodicitySheetState();
}

class _CarePeriodicitySheetState extends ConsumerState<CarePeriodicitySheet> {
  late CarePeriodicityChoice _choice;
  late final TextEditingController _custom;

  bool _submitting = false;
  bool _offline = false;
  String? _banner;

  @override
  void initState() {
    super.initState();
    _choice = carePeriodicityChoiceFor(
      widget.plan,
      recommendedDays: widget.defaultIntervalDays,
    );
    _custom = TextEditingController(
      text: widget.plan.intervalDays?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  String get _recommendedLabel {
    final phrase = intervalPhrase(days: widget.defaultIntervalDays);
    if (phrase == null) return 'Padrão recomendado';
    return 'Padrão recomendado ($phrase)';
  }

  Future<void> _submit() async {
    final customDays = _parsePositive(_custom.text);
    if (_choice == CarePeriodicityChoice.custom && customDays == null) {
      setState(() => _banner = 'Informe de quantos em quantos dias lembrar.');
      return;
    }
    if (_choice == CarePeriodicityChoice.recommended &&
        widget.defaultIntervalDays == null) {
      setState(() => _banner = 'Este item ainda não tem um padrão sugerido.');
      return;
    }

    setState(() {
      _submitting = true;
      _banner = null;
      _offline = false;
    });

    try {
      await ref
          .read(maintenancePlanRepositoryProvider)
          .update(
            widget.plan.id,
            carePeriodicityUpdate(
              choice: _choice,
              recommendedDays: widget.defaultIntervalDays,
              customDays: customDays,
            ),
          );
      invalidateAfterPlanWrite(ref, widget.vehicleId);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      showAppSnackBar(messenger, message: 'Lembrete atualizado.');
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        // Nothing on this sheet shows a field error, so all of them go here.
        _banner = ApiFormErrors.bannerOf(failure, shownFields: const []);
        _offline = ApiFormErrors.isOffline(failure);
      });
    }
  }

  void _choose(CarePeriodicityChoice choice) {
    if (_submitting) return;
    setState(() => _choice = choice);
  }

  @override
  Widget build(BuildContext context) {
    final options = <(CarePeriodicityChoice, String)>[
      (CarePeriodicityChoice.recommended, _recommendedLabel),
      (CarePeriodicityChoice.weekly, 'Toda semana'),
      (CarePeriodicityChoice.everyFifteenDays, 'A cada 15 dias'),
      (CarePeriodicityChoice.monthly, 'Todo mês'),
      (CarePeriodicityChoice.custom, 'Personalizado…'),
      (CarePeriodicityChoice.dontRemind, 'Não lembrar'),
    ];

    return AppSheetBody(
      children: [
        AppSheetHeader(
          title: widget.plan.itemName,
          subtitle: 'De quanto em quanto tempo lembrar',
          closable: false,
        ),
        const SizedBox(height: AppSpacing.s16),
        if (_banner != null) AuthFormBanner(message: _banner!),
        AppGroup(
          dividerIndent: 0,
          children: [
            for (final (choice, label) in options)
              AppChoiceRow<CarePeriodicityChoice>(
                value: choice,
                groupValue: _choice,
                label: label,
                enabled: !_submitting,
                onChanged: _choose,
              ),
          ],
        ),
        if (_choice == CarePeriodicityChoice.custom) ...[
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _custom,
            enabled: !_submitting,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: _submitting ? null : (_) => _submit(),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              // The server takes up to 3650 days — ten years.
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: const InputDecoration(
              labelText: 'A cada quantos dias',
              suffixText: 'dias',
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s24),
        AppButton(
          label: _offline ? 'Tentar de novo' : 'Salvar',
          loading: _submitting,
          onPressed: _submitting ? null : _submit,
          expanded: true,
        ),
      ],
    );
  }
}

int? _parsePositive(String raw) {
  final parsed = int.tryParse(raw.trim());
  if (parsed == null || parsed < 1) return null;
  return parsed;
}
