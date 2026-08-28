import 'package:flutter/material.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento_copy.dart';
import 'package:meu_auto/features/abastecimento/domain/volume.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_metric.dart';

/// The last fill on Início, as a section rather than a card.
///
/// Three figures side by side under a label reads faster than the same three
/// inside a bordered box, and it puts this block on the same footing as the
/// rest of the screen. Absent on a vehicle that does not refuel — not a
/// disabled card: an electric car has no last fill to be missing.
///
/// The name is historical. It stopped being a card when the dashboard did.
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
      return AppListRow(
        icon: Icons.local_gas_station_outlined,
        title: lastAbastecimentoEmptyPrompt,
        onTap: onRegister ?? onTap,
        showChevron: (onRegister ?? onTap) != null,
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kmPerLiter = consumptionValueText(fill.consumption);

    final header = Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              'Último abastecimento',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
        Text(
          formatCivilDayMonth(fill.occurredOn),
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: AppSpacing.s4),
          Icon(Icons.chevron_right, size: 20, color: scheme.outline),
        ],
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

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: AppSpacing.s8),
        figures,
      ],
    );

    if (onTap == null) {
      return body;
    }

    return Semantics(
      button: true,
      label:
          'Último abastecimento em ${formatCivilDayMonth(fill.occurredOn)}. '
          '${fill.totalCostCents.format()}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.borderS,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
            child: body,
          ),
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
