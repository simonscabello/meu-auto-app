import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/application/load_more_scroll.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento_copy.dart';
import 'package:meu_auto/features/timeline/application/timeline_provider.dart';
import 'package:meu_auto/features/timeline/domain/timeline_entry.dart';
import 'package:meu_auto/features/timeline/presentation/add_record_sheet.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_timeline_tile.dart';

/// Histórico tab: the unified timeline of the selected vehicle.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedVehicleProvider);
    final vehicle = selected.value;

    return AppScaffold(
      title: 'Histórico',
      actions: [
        if (vehicle != null)
          AppIconButton(
            label: 'Adicionar registro',
            icon: Icons.add,
            onPressed: () => AddRecordSheet.show(context),
          ),
      ],
      onRefresh: vehicle == null ? null : () => _refresh(ref, vehicle.id),
      body: selected.when(
        loading: () => const _TimelineSkeleton(),
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

    return history.when(
      loading: () => const _TimelineSkeleton(),
      error: (error, _) => AppErrorState.fromError(
        error: error,
        onRetry: () => ref.invalidate(timelineProvider(widget.vehicleId)),
      ),
      data: (state) => TimelineContent(
        state: state,
        scroll: _scroll,
        onOpen: (entry) => _open(entry),
        onAddRecord: () => AddRecordSheet.show(context),
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

/// The timeline as pure presentation.
///
/// History is a sequence, so it is drawn as one: a rail down the left with a
/// node per event, grouped under the day it happened. It used to be a stack
/// of bordered cards, which said nothing about order and made twenty entries
/// look like twenty unrelated objects.
///
/// Three things the shape has to deliver, and each is a layout decision:
///
///  * **Dates found at a glance** — the day header pins to the top while its
///    events scroll under it, so the reader always knows which day they are
///    looking at.
///  * **Mileage and money legible as a column** — both are set in tabular
///    figures, right-aligned, so the numbers line up down the page.
///  * **Kinds told apart** — a small icon per event, and the type as the
///    subtitle when the server did not send one.
class TimelineContent extends StatelessWidget {
  const TimelineContent({
    super.key,
    required this.state,
    this.scroll,
    this.onOpen,
    this.onAddRecord,
    this.onRetryPage,
  });

  final PagedState<TimelineEntry> state;
  final ScrollController? scroll;
  final ValueChanged<TimelineEntry>? onOpen;
  final VoidCallback? onAddRecord;
  final VoidCallback? onRetryPage;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return _EmptyHistory(onAddRecord: onAddRecord);
    }

    final days = groupTimelineByDate(state.items);
    final scheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      controller: scroll,
      slivers: [
        for (final day in days) ...[
          SliverPersistentHeader(
            pinned: true,
            delegate: _DayHeaderDelegate(
              label: day.label,
              year: day.year,
              weekday: day.weekday,
            ),
          ),
          // One surface per day rather than tiles straight on the page. The
          // rail still carries the order inside the day; the surface is what
          // says where the day ends — and it is the same bounded group every
          // other list in the app now sits in.
          //
          // A box adapter, not a SliverList: a day holds a handful of events,
          // and the laziness that a sliver list would keep is not worth a
          // decoration that cannot wrap one.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                0,
                AppSpacing.s16,
                AppSpacing.s24,
              ),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: groupSurfaceColor(scheme),
                  borderRadius: AppRadius.borderM,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8,
                    vertical: AppSpacing.s4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < day.entries.length; i++)
                        _EntryTile(
                          entry: day.entries[i],
                          isLast: i == day.entries.length - 1,
                          onTap:
                              onOpen != null &&
                                  routeForTimelineEntry(day.entries[i]) != null
                              ? () => onOpen!(day.entries[i])
                              : null,
                        ),
                    ],
                  ),
                ),
              ),
            ),
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
  const TimelineDateGroup({
    required this.label,
    required this.year,
    required this.weekday,
    required this.entries,
  });

  final String label;

  /// Short and lower case. A day of the month is a lookup; a weekday is a
  /// memory.
  final String weekday;

  /// Shown beside the day, quietly. A history that goes back three years is
  /// unreadable without it, and it is the wrong thing to make anyone scroll
  /// to work out.
  final int year;

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
          year: entry.occurredOn.year,
          weekday: formatCivilWeekdayShort(entry.occurredOn),
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
  const _EmptyHistory({this.onAddRecord});

  final VoidCallback? onAddRecord;

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
        AppButton(label: 'Adicionar registro', onPressed: onAddRecord),
      ],
    );
  }
}

/// The pinned day header.
///
/// It carries the page background so the rows scrolling beneath it are hidden
/// rather than showing through, and the rail is redrawn inside it so the line
/// appears continuous across the join.
class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DayHeaderDelegate({
    required this.label,
    required this.year,
    required this.weekday,
  });

  final String label;
  final int year;
  final String weekday;

  @override
  double get minExtent => 46;

  @override
  double get maxExtent => 46;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s4,
      ),
      child: Text.rich(
        TextSpan(
          text: label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            letterSpacing: 0.6,
            fontFeatures: AppTypography.tabular,
          ),
          children: [
            TextSpan(
              text: ' $year · $weekday',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_DayHeaderDelegate oldDelegate) =>
      oldDelegate.label != label ||
      oldDelegate.year != year ||
      oldDelegate.weekday != weekday;
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.isLast, this.onTap});

  final TimelineEntry entry;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = entry.amountCents;
    final showAmount = amount != null && amount.cents > 0;
    final mileage = entry.mileageKm;

    return AppTimelineTile(
      title: titleOf(entry),
      subtitle: _subtitleOf(entry),
      icon: _iconFor(entry),
      isLast: isLast,
      onTap: onTap,
      trailing: (showAmount || mileage != null)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (showAmount)
                  Text(
                    amount.format(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                if (mileage != null)
                  Text(
                    formatKm(mileage),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
              ],
            )
          : null,
    );
  }
}

IconData _iconFor(TimelineEntry entry) {
  if (entry.care == true) return Icons.checklist_rtl;
  return switch (entry.kind) {
    TimelineEntryKind.manutencao => Icons.build_outlined,
    TimelineEntryKind.odometro => Icons.speed_outlined,
    TimelineEntryKind.ipva => Icons.receipt_long_outlined,
    TimelineEntryKind.licenciamento => Icons.description_outlined,
    TimelineEntryKind.abastecimento => Icons.local_gas_station_outlined,
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
    return const SizedBox(height: AppSpacing.s32);
  }
}

/// Mirrors the timeline: a day header, then a few nodes under it.
class _TimelineSkeleton extends StatelessWidget {
  const _TimelineSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s32,
      ),
      children: const [
        AppSkeleton(width: 96, height: 14),
        SizedBox(height: AppSpacing.s16),
        AppSkeletonList(count: 3, itemHeight: 40),
        SizedBox(height: AppSpacing.s32),
        AppSkeleton(width: 96, height: 14),
        SizedBox(height: AppSpacing.s16),
        AppSkeletonList(count: 2, itemHeight: 40),
      ],
    );
  }
}
