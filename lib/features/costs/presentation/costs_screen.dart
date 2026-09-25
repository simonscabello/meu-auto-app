import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/features/costs/application/costs_provider.dart';
import 'package:meu_auto/features/costs/domain/costs_copy.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_group_scope.dart';
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
///
/// Three things, top to bottom: the window, the figure, and what it is made
/// of. The figure is the screen, so it stands on the page as a reading; the
/// categories are one group, one line each.
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

    return ListView(
      // Pull-to-refresh needs a scrollable even when everything fits.
      physics: const AlwaysScrollableScrollPhysics(),
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
        _Total(
          amount: costs.totalCents,
          window: 'Nos ${costWindowLabel(costs.periodMonths)}',
        ),
        if (empty) ...[
          const SizedBox(height: AppSpacing.s16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Text(
              emptyPeriodPhrase(costs.periodMonths),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (excluded != null) ...[
            const SizedBox(height: AppSpacing.s8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
              child: Text(excluded, style: theme.textTheme.bodySmall),
            ),
          ],
        ] else ...[
          const SizedBox(height: appGroupGap),
          AppGroup(
            title: 'Por categoria',
            dividerIndent: AppGroup.textIndent,
            footnote: excluded,
            children: [
              for (final bar in costs.bars)
                _CategoryBar(
                  label: bar.label,
                  amount: bar.cents,
                  trackedCents: total,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The total as a reading, the way Início sets the mileage: the figure large
/// and tabular, the currency beside it quieter, the window under it.
class _Total extends StatelessWidget {
  const _Total({required this.amount, required this.window});

  final Money amount;
  final String window;

  static const _symbol = 'R\$$nbsp';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formatted = amount.format();
    final hasSymbol = formatted.startsWith(_symbol);
    final figure = hasSymbol ? formatted.substring(_symbol.length) : formatted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Custo registrado',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          // Scaled down rather than wrapped: seven figures at a large text
          // size are wider than a small phone, and a total split over two
          // lines is not a total.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  if (hasSymbol)
                    TextSpan(
                      text: _symbol,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  TextSpan(
                    text: figure,
                    style: AppTypography.figure(
                      size: 44,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(window, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// One category: its name and amount on one line, and under them a thin bar
/// of its share of the total with the share in figures at its end.
class _CategoryBar extends StatelessWidget with GroupedRow {
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The name wraps before the amount moves; a wide amount or a large
          // text size puts it under the name (AppRowBody).
          AppRowBody(title: label, titleMaxLines: 2, value: amount.format()),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              Expanded(
                child: AppProgressBar(
                  value: fraction,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              // A fixed column, so every bar in the group ends at the same
              // place whatever its share reads.
              SizedBox(
                width: AppSpacing.s40,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$percent%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The note stands on its own line, so it starts as a sentence does. When
/// fuel is counted the copy begins with "despesas", which read as a line cut
/// off at the front.
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
        AppSkeleton(width: double.infinity, height: 48),
        SizedBox(height: AppSpacing.block),
        AppSkeleton(width: 120, height: 14),
        SizedBox(height: AppSpacing.s12),
        AppSkeleton(width: 220, height: 44),
        SizedBox(height: AppSpacing.s8),
        AppSkeleton(width: 140, height: 12),
        SizedBox(height: appGroupGap),
        AppSkeleton(width: double.infinity, height: 220),
      ],
    );
  }
}
