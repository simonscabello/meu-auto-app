import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/features/costs/application/costs_provider.dart';
import 'package:meu_auto/features/costs/domain/costs_copy.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_progress_bar.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_segmented.dart';
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
    final scheme = theme.colorScheme;
    final total = costs.totalCents.cents;
    final empty = total <= 0;
    final excluded = excludedCategoriesNote(costs.noteCategoryKeys);
    final window = costWindowLabel(costs.periodMonths);
    final bars = costs.bars;

    return ListView(
      padding: AppSpacing.screen,
      children: [
        AppSegmented<int>(
          value: selectedMonths,
          onChanged: onPeriodSelected,
          options: [
            for (final months in _periodOptions)
              AppSegmentedOption(value: months, label: '$months meses'),
          ],
        ),
        const SizedBox(height: AppSpacing.block),
        // The total is the screen, so it is set as the screen's own reading
        // rather than boxed. A card here would put the one figure everything
        // else is measured against on the same footing as the bars below it.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Custo registrado',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  costs.totalCents.format(),
                  style: AppTypography.figure(
                    size: 48,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                window,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
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
        const SizedBox(height: AppSpacing.block),
        AppGroup(
          title: 'Por categoria',
          dividerIndent: 0,
          footnote: excluded,
          children: [
            for (final bar in bars)
              _CategoryBar(
                label: bar.label,
                amount: bar.cents,
                trackedCents: total,
              ),
          ],
        ),
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

    return AppListRowShell(
      semanticLabel: '$label. ${amount.format()}. $percent por cento',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.s4),
          // The figure and its share on a line of their own, so a long
          // category name at a large text scale never pushes them off the
          // edge.
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    amount.format(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
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
          const SizedBox(height: AppSpacing.s12),
          AppProgressBar(value: fraction, height: 6),
        ],
      ),
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
      padding: AppSpacing.screen,
      children: const [
        AppSkeleton(width: double.infinity, height: 46),
        SizedBox(height: AppSpacing.block),
        AppSkeleton(width: 140, height: 14),
        SizedBox(height: AppSpacing.s12),
        AppSkeleton(width: 220, height: 48),
        SizedBox(height: AppSpacing.block),
        AppSkeleton(width: double.infinity, height: 220),
      ],
    );
  }
}
