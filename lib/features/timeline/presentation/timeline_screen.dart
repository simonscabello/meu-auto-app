import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/application/load_more_scroll.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento_copy.dart';
import 'package:meu_auto/features/odometer/presentation/odometer_sheet.dart';
import 'package:meu_auto/features/timeline/application/timeline_provider.dart';
import 'package:meu_auto/features/timeline/domain/timeline_entry.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_card.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

/// Histórico tab: the unified timeline of the selected vehicle.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedVehicleProvider);
    final vehicle = selected.value;

    return AppScaffold(
      title: 'Histórico',
      onRefresh: vehicle == null ? null : () => _refresh(ref, vehicle.id),
      body: selected.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.s16),
          child: AppSkeletonList(count: 5, itemHeight: 88),
        ),
        error: (error, _) => AppErrorState.fromError(
          error: error,
          onRetry: () => ref.read(vehiclesProvider.notifier).reload(),
        ),
        data: (current) => current == null
            ? const SizedBox.shrink()
            : TimelineView(vehicleId: current.id),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref, String vehicleId) async {
    ref.invalidate(timelineProvider(vehicleId));
    try {
      await ref.read(timelineProvider(vehicleId).future);
    } on Object {
      // The provider already holds the failure; TimelineView renders it.
    }
  }
}

class TimelineView extends ConsumerStatefulWidget {
  const TimelineView({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends ConsumerState<TimelineView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (shouldLoadMore(_scroll)) {
      ref.read(timelineProvider(widget.vehicleId).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(timelineProvider(widget.vehicleId));
    final vehicle = ref.watch(selectedVehicleProvider).value;

    return history.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.s16),
        child: AppSkeletonList(count: 5, itemHeight: 88),
      ),
      error: (error, _) => AppErrorState.fromError(
        error: error,
        onRetry: () => ref.invalidate(timelineProvider(widget.vehicleId)),
      ),
      data: (state) => TimelineContent(
        state: state,
        scroll: _scroll,
        onOpen: (entry) => _open(entry),
        onRegisterMaintenance: () => context.push(AppRoutes.maintenanceNew),
        onRegisterOdometer: vehicle == null
            ? null
            : () => OdometerSheet.show(
                context,
                vehicleId: vehicle.id,
                currentMileageKm: vehicle.currentMileageKm,
              ),
        onRetryPage: () =>
            ref.read(timelineProvider(widget.vehicleId).notifier).loadMore(),
      ),
    );
  }

  void _open(TimelineEntry entry) {
    final route = routeForTimelineEntry(entry);
    if (route == null) return;
    context.push(route);
  }
}

/// The timeline as pure presentation. Receives the loaded page and never
/// touches a provider — grouping, fallback titles and which route to open
/// are decisions this widget (and [routeForTimelineEntry]) own.
class TimelineContent extends StatelessWidget {
  const TimelineContent({
    super.key,
    required this.state,
    this.scroll,
    this.onOpen,
    this.onRegisterMaintenance,
    this.onRegisterOdometer,
    this.onRetryPage,
  });

  final PagedState<TimelineEntry> state;
  final ScrollController? scroll;
  final ValueChanged<TimelineEntry>? onOpen;
  final VoidCallback? onRegisterMaintenance;
  final VoidCallback? onRegisterOdometer;
  final VoidCallback? onRetryPage;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return _EmptyHistory(
        onRegisterMaintenance: onRegisterMaintenance,
        onRegisterOdometer: onRegisterOdometer,
      );
    }

    final days = groupTimelineByDate(state.items);

    return CustomScrollView(
      controller: scroll,
      slivers: [
        for (final day in days) ...[
          SliverPersistentHeader(
            pinned: true,
            delegate: _MonthHeaderDelegate(label: day.label),
          ),
          SliverList.builder(
            itemCount: day.entries.length,
            itemBuilder: (context, index) {
              final entry = day.entries[index];
              final canOpen =
                  onOpen != null && routeForTimelineEntry(entry) != null;
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  0,
                  AppSpacing.s16,
                  AppSpacing.s8,
                ),
                child: _EntryTile(
                  entry: entry,
                  onTap: canOpen ? () => onOpen!(entry) : null,
                ),
              );
            },
          ),
        ],
        SliverToBoxAdapter(
          child: _Footer(state: state, onRetry: onRetryPage),
        ),
      ],
    );
  }
}

final class TimelineDateGroup {
  const TimelineDateGroup({required this.label, required this.entries});

  final String label;
  final List<TimelineEntry> entries;
}

/// The list already arrives newest first, so a group closes wherever the
/// civil day changes — no sorting, no second pass.
@visibleForTesting
List<TimelineDateGroup> groupTimelineByDate(List<TimelineEntry> entries) {
  final groups = <TimelineDateGroup>[];
  CivilDate? day;
  for (final entry in entries) {
    if (entry.occurredOn != day) {
      day = entry.occurredOn;
      groups.add(
        TimelineDateGroup(
          label: formatCivilDayMonthShort(entry.occurredOn),
          entries: <TimelineEntry>[],
        ),
      );
    }
    groups.last.entries.add(entry);
  }
  return groups;
}

/// Where a tap should go. `null` means the row is not tappable — an unknown
/// `kind` has nowhere to land, and inventing a screen would be a guess.
@visibleForTesting
String? routeForTimelineEntry(TimelineEntry entry) {
  return switch (entry.kind) {
    TimelineEntryKind.manutencao => AppRoutes.maintenanceRecord(entry.id),
    TimelineEntryKind.odometro => AppRoutes.odometer,
    TimelineEntryKind.ipva => AppRoutes.obligation(entry.id),
    TimelineEntryKind.licenciamento => AppRoutes.obligation(entry.id),
    TimelineEntryKind.abastecimento => AppRoutes.abastecimento(entry.id),
    TimelineEntryKind.desconhecido => null,
  };
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({this.onRegisterMaintenance, this.onRegisterOdometer});

  final VoidCallback? onRegisterMaintenance;
  final VoidCallback? onRegisterOdometer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.s24),
      children: [
        const SizedBox(height: AppSpacing.s32),
        Text(
          'O histórico do seu carro começa aqui',
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          'Cada manutenção, quilometragem e pagamento registrado vira o '
          'histórico que o carro leva na revenda.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.s24),
        AppButton(
          label: 'Registrar manutenção',
          onPressed: onRegisterMaintenance,
        ),
        const SizedBox(height: AppSpacing.s8),
        AppButton(
          label: 'Registrar quilometragem',
          variant: AppButtonVariant.secondary,
          onPressed: onRegisterOdometer,
        ),
      ],
    );
  }
}

class _MonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  _MonthHeaderDelegate({required this.label});

  final String label;

  @override
  double get minExtent => 44;

  @override
  double get maxExtent => 44;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_MonthHeaderDelegate oldDelegate) =>
      oldDelegate.label != label;
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, this.onTap});

  final TimelineEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = _subtitleOf(entry);
    final amount = entry.amountCents;
    final showAmount = amount != null && amount.cents > 0;
    final mileage = entry.mileageKm;

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconFor(entry), color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleOf(entry),
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showAmount || mileage != null) ...[
            const SizedBox(width: AppSpacing.s8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (showAmount)
                  Text(
                    amount.format(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                if (mileage != null) ...[
                  if (showAmount) const SizedBox(height: AppSpacing.s4),
                  Text(
                    formatKm(mileage),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

IconData _iconFor(TimelineEntry entry) {
  if (entry.care == true) return Icons.checklist;
  return switch (entry.kind) {
    TimelineEntryKind.manutencao => Icons.build,
    TimelineEntryKind.odometro => Icons.speed,
    TimelineEntryKind.ipva => Icons.receipt_long,
    TimelineEntryKind.licenciamento => Icons.description,
    TimelineEntryKind.abastecimento => Icons.local_gas_station,
    TimelineEntryKind.desconhecido => Icons.history,
  };
}

String? _subtitleOf(TimelineEntry entry) {
  final raw = entry.subtitle?.trim();
  if (raw == null || raw.isEmpty) return null;
  if (entry.kind != TimelineEntryKind.abastecimento) return raw;
  final fuel = AbastecimentoFuel.fromWire(raw);
  if (fuel == AbastecimentoFuel.desconhecido) return raw;
  return abastecimentoFuelLabel(fuel);
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state, this.onRetry});

  final PagedState<TimelineEntry> state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.lastPageError != null) {
      final error = state.lastPageError;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
        child: Column(
          children: [
            Text(
              error is ApiFailure
                  ? error.message
                  : 'Não foi possível carregar mais.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            AppButton(
              label: 'Tentar de novo',
              variant: AppButtonVariant.tertiary,
              onPressed: onRetry,
            ),
          ],
        ),
      );
    }
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.s24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return const SizedBox(height: AppSpacing.s24);
  }
}
