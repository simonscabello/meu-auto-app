import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/auth/presentation/auth_form_banner.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/plan_update.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_number_field.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

class PlanIntervalSheet extends ConsumerStatefulWidget {
  const PlanIntervalSheet({
    super.key,
    required this.vehicleId,
    required this.plan,
  });

  final String vehicleId;
  final MaintenancePlan plan;

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
      builder: (sheetContext) =>
          PlanIntervalSheet(vehicleId: vehicleId, plan: plan),
    );
  }

  @override
  ConsumerState<PlanIntervalSheet> createState() => _PlanIntervalSheetState();
}

class _PlanIntervalSheetState extends ConsumerState<PlanIntervalSheet> {
  late final TextEditingController _km;
  late final TextEditingController _months;
  late final TextEditingController _days;
  late final TextEditingController _alertKm;
  late final TextEditingController _alertDays;

  bool _submitting = false;
  bool _offline = false;
  String? _banner;
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _km = TextEditingController(text: _kmDigits(plan.intervalKm));
    _months = TextEditingController(text: _digits(plan.intervalMonths));
    _days = TextEditingController(text: _digits(plan.intervalDays));
    _alertKm = TextEditingController(text: formatKmNumber(plan.alertKm));
    _alertDays = TextEditingController(text: plan.alertDays.toString());
  }

  @override
  void dispose() {
    _km.dispose();
    _months.dispose();
    _days.dispose();
    _alertKm.dispose();
    _alertDays.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final km = _parsePositive(_km.text);
    final months = _parsePositive(_months.text);
    final days = _parsePositive(_days.text);
    if (km == null && months == null && days == null) {
      setState(() {
        _banner =
            'Informe ao menos um intervalo, ou escolha guardar só o histórico.';
        _fieldErrors = {};
      });
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
          .read(maintenancePlanRepositoryProvider)
          .update(
            widget.plan.id,
            PlanUpdate.intervals(
              intervalKm: km,
              intervalMonths: months,
              intervalDays: days,
              alertKm: _parseNonNegative(_alertKm.text),
              alertDays: _parseNonNegative(_alertDays.text),
            ),
          );
      invalidateAfterPlanWrite(ref, widget.vehicleId);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      showAppSnackBar(messenger, message: 'Intervalo atualizado.');
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _fieldErrors = ApiFormErrors.fieldsOf(failure);
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
            Text('Ajustar intervalo', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Os intervalos sugeridos são padrões genéricos de mercado, '
              'não a especificação do fabricante do seu carro.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            if (_banner != null) AuthFormBanner(message: _banner!),
            _kmField(
              controller: _km,
              label: 'A cada quantos km',
              fieldKey: 'interval_km',
            ),
            _numberField(
              controller: _months,
              label: 'A cada quantos meses',
              fieldKey: 'interval_months',
            ),
            _numberField(
              controller: _days,
              label: 'A cada quantos dias',
              fieldKey: 'interval_days',
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Avisar com antecedência de',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.s8),
            _kmField(
              controller: _alertKm,
              label: 'Quilômetros',
              fieldKey: 'alert_km',
            ),
            _numberField(
              controller: _alertDays,
              label: 'Dias',
              fieldKey: 'alert_days',
              textInputAction: TextInputAction.done,
              onSubmitted: _submitting ? null : _submit,
            ),
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

  /// Kilometres, masked like every other kilometre the app shows. Months and
  /// days stay plain: a two-digit number has no thousands to group.
  Widget _kmField({
    required TextEditingController controller,
    required String label,
    required String fieldKey,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: AppKmField(
        controller: controller,
        label: label,
        enabled: !_submitting,
        errorText: _fieldErrors[fieldKey],
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String fieldKey,
    TextInputAction textInputAction = TextInputAction.next,
    VoidCallback? onSubmitted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: TextField(
        controller: controller,
        enabled: !_submitting,
        keyboardType: TextInputType.number,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(7),
        ],
        decoration: InputDecoration(
          labelText: label,
          errorText: _fieldErrors[fieldKey],
          errorMaxLines: 3,
        ),
      ),
    );
  }
}

String _digits(int? value) => value == null ? '' : value.toString();

String _kmDigits(int? value) => value == null ? '' : formatKmNumber(value);

/// Reads the digits, so a masked `10.000` and a plain `10000` both parse.
int? _parsePositive(String raw) {
  final parsed = kmFromField(raw);
  if (parsed == null || parsed < 1) return null;
  return parsed;
}

int? _parseNonNegative(String raw) {
  final parsed = kmFromField(raw);
  if (parsed == null || parsed < 0) return null;
  return parsed;
}
