import 'package:flutter/material.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento_copy.dart';
import 'package:meu_auto/features/abastecimento/domain/volume.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_metric.dart';
import 'package:meu_auto/shared/widgets/app_surface.dart';

/// The last fill, as one block: when, and the three figures a person
/// compares fill to fill.
///
/// Lives on Histórico, beside what the car cost, because the consumption
/// figure is a reading of the past and not something to act on now. Absent
/// on a vehicle that does not refuel — not a disabled block: an electric car
/// has no last fill to be missing.
class LastAbastecimentoCard extends StatelessWidget {
  const LastAbastecimentoCard({
    super.key,
    required this.supported,
    this.last,
    this.onTap,
    this.onRegister,
  });

  final bool supported;
  final LastAbastecimento? last;
  final VoidCallback? onTap;
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    if (!supported) return const SizedBox.shrink();

    final fill = last;
    if (fill == null) {
      // Deliberately not the list's empty state: this is an invitation on a
      // screen about something else, not a screen with nothing on it.
      return AppGroup(
        children: [
          AppListRow(
            icon: Icons.local_gas_station_outlined,
            iconTone: AppIconWellTone.accent,
            title: lastAbastecimentoEmptyPrompt,
            onTap: onRegister ?? onTap,
            showChevron: (onRegister ?? onTap) != null,
          ),
        ],
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kmPerLiter = consumptionValueText(fill.consumption);
    final when = formatCivilDayMonth(fill.occurredOn);

    final header = Row(
      children: [
        const AppIconWell(icon: Icons.local_gas_station_outlined),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Último abastecimento',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                when,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null)
          Icon(Icons.chevron_right, size: 20, color: scheme.outline),
      ],
    );

    final figures = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _FitMetric(
            child: AppMetric(
              value: fill.totalCostCents.format(),
              size: AppMetricSize.compact,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: _FitMetric(
            child: AppMetric(
              value: litersTextFromVolumeMl(fill.volumeMl),
              unit: 'L',
              size: AppMetricSize.compact,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          flex: kmPerLiter == null ? 2 : 1,
          child: kmPerLiter == null
              ? Text(
                  consumptionPhrase(fill.consumption),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              : _FitMetric(
                  child: AppMetric(
                    value: kmPerLiter,
                    unit: 'km/L',
                    size: AppMetricSize.compact,
                  ),
                ),
        ),
      ],
    );

    return Semantics(
      button: onTap != null,
      label:
          'Último abastecimento em $when. '
          '${fill.totalCostCents.format()}',
      excludeSemantics: true,
      child: AppSurface(
        variant: AppSurfaceVariant.grouped,
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            const SizedBox(height: AppSpacing.s16),
            figures,
          ],
        ),
      ),
    );
  }
}

class _FitMetric extends StatelessWidget {
  const _FitMetric({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}
