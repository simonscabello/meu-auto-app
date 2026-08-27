import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/features/costs/application/costs_provider.dart';
import 'package:meu_auto/features/costs/domain/costs_copy.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';
import 'package:meu_auto/shared/widgets/app_card.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

const _periodOptions = [3, 6, 12, 24];

class CostsScreen extends ConsumerStatefulWidget {
  const CostsScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<CostsScreen> createState() => _CostsScreenState();
}

class _CostsScreenState extends ConsumerState<CostsScreen> {
  int _months = 12;

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(
      costsDashboardProvider((vehicleId: widget.vehicleId, months: _months)),
    );

    return AppScaffold(
      title: 'Custos',
      onRefresh: () => _refresh(),
      body: dashboard.when(
        loading: () => const _CostsSkeleton(),
        error: (error, _) =>
            AppErrorState.fromError(error: error, onRetry: _refresh),
        data: (data) => CostsContent(
          costs: data.costs,
          selectedMonths: _months,
          onPeriodSelected: (months) => setState(() => _months = months),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(
      costsDashboardProvider((vehicleId: widget.vehicleId, months: _months)),
    );
    try {
      await ref.read(
        costsDashboardProvider((
          vehicleId: widget.vehicleId,
          months: _months,
        )).future,
      );
    } on Object {
      // The provider already holds the failure; the screen renders it.
    }
  }
}

/// Pure presentation of the cost summary. Every figure arrived from the
/// server — [DashboardCosts.totalCents] is the total, and the bars only
/// scale against it. Nothing here adds the categories up.
class CostsContent extends StatelessWidget {
  const CostsContent({
    super.key,
    required this.costs,
    required this.selectedMonths,
    this.onPeriodSelected,
  });

  final DashboardCosts costs;
  final int selectedMonths;
  final ValueChanged<int>? onPeriodSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = costs.totalCents.cents;
    final empty = total <= 0;
    final excluded = excludedCategoriesNote(costs.noteCategoryKeys);
    final window = costWindowLabel(costs.periodMonths);
    final bars = costs.bars;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            for (final months in _periodOptions)
              ChoiceChip(
                label: Text('$months meses'),
                selected: selectedMonths == months,
                onSelected: onPeriodSelected == null
                    ? null
                    : (_) => onPeriodSelected!(months),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s24),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Custo registrado',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                costs.totalCents.format(),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFeatures: AppTypography.tabular,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                window,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (empty) ...[
                const SizedBox(height: AppSpacing.s12),
                Text(
                  emptyPeriodPhrase(costs.periodMonths),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s24),
        for (var i = 0; i < bars.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.s16),
          _CategoryBar(
            label: bars[i].label,
            amount: bars[i].cents,
            trackedCents: total,
          ),
        ],
        if (excluded != null) ...[
          const SizedBox(height: AppSpacing.s24),
          Text(
            excluded,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.label,
    required this.amount,
    required this.trackedCents,
  });

  final String label;
  final Money amount;
  final int trackedCents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cents = amount.cents;
    final fraction = _barFraction(cents, trackedCents);
    final percent = _percent(cents, trackedCents);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              amount.format(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontFeatures: AppTypography.tabular,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              '$percent%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              height: 8,
              width: constraints.maxWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: AppRadius.borderS,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: constraints.maxWidth * fraction,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: AppRadius.borderS,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Layout only: how much of the track this category occupies. The total is
/// [trackedCents] from the server — this does not add the other categories.
double _barFraction(int cents, int trackedCents) {
  if (trackedCents <= 0 || cents <= 0) return 0;
  final fraction = cents / trackedCents;
  if (fraction > 1) return 1;
  return fraction;
}

int _percent(int cents, int trackedCents) {
  if (trackedCents <= 0 || cents <= 0) return 0;
  final percent = (cents * 100) ~/ trackedCents;
  if (percent > 100) return 100;
  return percent;
}

class _CostsSkeleton extends StatelessWidget {
  const _CostsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: const [
        AppSkeleton(width: double.infinity, height: 40),
        SizedBox(height: AppSpacing.s24),
        AppSkeleton(width: double.infinity, height: 112),
        SizedBox(height: AppSpacing.s24),
        AppSkeleton(width: double.infinity, height: 40),
        SizedBox(height: AppSpacing.s16),
        AppSkeleton(width: double.infinity, height: 40),
        SizedBox(height: AppSpacing.s16),
        AppSkeleton(width: double.infinity, height: 40),
      ],
    );
  }
}
