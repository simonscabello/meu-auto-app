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
import 'package:meu_auto/shared/widgets/app_button.dart';
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
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
        _banner = ApiFormErrors.bannerOf(failure);
        _offline = ApiFormErrors.isOffline(failure);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.s24,
        right: AppSpacing.s24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.s24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.plan.itemName, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s8),
            Text('Lembrar:', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.s8),
            if (_banner != null) AuthFormBanner(message: _banner!),
            RadioGroup<CarePeriodicityChoice>(
              groupValue: _choice,
              onChanged: (choice) {
                if (_submitting || choice == null) return;
                setState(() => _choice = choice);
              },
              child: Column(
                children: [
                  RadioListTile<CarePeriodicityChoice>(
                    value: CarePeriodicityChoice.recommended,
                    title: Text(_recommendedLabel),
                    contentPadding: EdgeInsets.zero,
                    enabled: !_submitting,
                  ),
                  RadioListTile<CarePeriodicityChoice>(
                    value: CarePeriodicityChoice.weekly,
                    title: const Text('Toda semana'),
                    contentPadding: EdgeInsets.zero,
                    enabled: !_submitting,
                  ),
                  RadioListTile<CarePeriodicityChoice>(
                    value: CarePeriodicityChoice.everyFifteenDays,
                    title: const Text('A cada 15 dias'),
                    contentPadding: EdgeInsets.zero,
                    enabled: !_submitting,
                  ),
                  RadioListTile<CarePeriodicityChoice>(
                    value: CarePeriodicityChoice.monthly,
                    title: const Text('Todo mês'),
                    contentPadding: EdgeInsets.zero,
                    enabled: !_submitting,
                  ),
                  RadioListTile<CarePeriodicityChoice>(
                    value: CarePeriodicityChoice.custom,
                    title: const Text('Personalizado…'),
                    contentPadding: EdgeInsets.zero,
                    enabled: !_submitting,
                  ),
                  RadioListTile<CarePeriodicityChoice>(
                    value: CarePeriodicityChoice.dontRemind,
                    title: const Text('Não lembrar'),
                    contentPadding: EdgeInsets.zero,
                    enabled: !_submitting,
                  ),
                ],
              ),
            ),
            if (_choice == CarePeriodicityChoice.custom) ...[
              const SizedBox(height: AppSpacing.s8),
              TextField(
                controller: _custom,
                enabled: !_submitting,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: _submitting ? null : (_) => _submit(),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(7),
                ],
                decoration: const InputDecoration(
                  labelText: 'A cada quantos dias',
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s16),
            AppButton(
              label: _offline ? 'Tentar de novo' : 'Salvar',
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

int? _parsePositive(String raw) {
  final parsed = int.tryParse(raw.trim());
  if (parsed == null || parsed < 1) return null;
  return parsed;
}
