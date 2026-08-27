import 'package:flutter/material.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento_copy.dart';
import 'package:meu_auto/features/abastecimento/domain/volume.dart';
import 'package:meu_auto/shared/widgets/app_card.dart';
import 'package:meu_auto/shared/widgets/app_metric.dart';

/// Last fill on Início. Absent on a vehicle that does not refuel — not a
/// disabled card.
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
      return AppCard(
        onTap: onRegister ?? onTap,
        child: Text(
          lastAbastecimentoEmptyPrompt,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final kmPerLiter = consumptionValueText(fill.consumption);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Último abastecimento',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                formatCivilDayMonth(fill.occurredOn),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _FitMetric(
                  child: AppMetric(value: fill.totalCostCents.format()),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: _FitMetric(
                  child: AppMetric(
                    value: litersTextFromVolumeMl(fill.volumeMl),
                    unit: 'L',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: kmPerLiter == null
                    ? Text(
                        consumptionPhrase(fill.consumption),
                        style: theme.textTheme.bodyMedium,
                      )
                    : _FitMetric(
                        child: AppMetric(value: kmPerLiter, unit: 'km/L'),
                      ),
              ),
            ],
          ),
        ],
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
