import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/client_id.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_item_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_record_provider.dart';
import 'package:meu_auto/features/maintenance/domain/cuidados_groups.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record_draft.dart';
import 'package:meu_auto/features/maintenance/domain/plan_copy.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_icons.dart';
import 'package:meu_auto/features/maintenance/presentation/plan_create_sheet.dart';
import 'package:meu_auto/features/obligation/application/obligation_provider.dart';
import 'package:meu_auto/features/obligation/presentation/documentos_section.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

class CuidadosScreen extends ConsumerWidget {
  const CuidadosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedVehicleProvider);
    final vehicle = selected.value;

    return AppScaffold(
      title: 'Cuidados',
      actions: [
        if (vehicle != null)
          AppIconButton(
            label: 'O que o seu carro tem',
            icon: Icons.tune,
            onPressed: () => context.push(AppRoutes.vehicleProfile),
          ),
      ],
      onRefresh: vehicle == null ? null : () => _refresh(ref, vehicle.id),
      body: selected.when(
        loading: () => const _CuidadosSkeleton(),
        error: (error, _) => AppErrorState.fromError(
          error: error,
          onRetry: () => ref.read(vehiclesProvider.notifier).reload(),
        ),
        data: (current) => current == null
            ? const SizedBox.shrink()
            : CuidadosView(vehicleId: current.id),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref, String vehicleId) async {
    ref.invalidate(maintenancePlansProvider(vehicleId));
    ref.invalidate(obligationsProvider(vehicleId));
    ref.invalidate(segurosProvider(vehicleId));
    try {
      await Future.wait([
        ref.read(maintenancePlansProvider(vehicleId).future),
        ref.read(obligationsProvider(vehicleId).future),
        ref.read(segurosProvider(vehicleId).future),
      ]);
    } on Object {
      // The providers already hold the failure; the view renders it.
    }
  }
}

class CuidadosView extends ConsumerStatefulWidget {
  const CuidadosView({super.key, required this.vehicleId, this.newId});

  final String vehicleId;
  final String Function()? newId;

  @override
  ConsumerState<CuidadosView> createState() => _CuidadosViewState();
}

class _CuidadosViewState extends ConsumerState<CuidadosView> {
  final _justRecorded = <String>{};
  final _submitting = <String>{};
  final _inFlightIds = <String, String>{};

  String get _vehicleId => widget.vehicleId;

  Future<void> _markDone(MaintenancePlan plan) async {
    if (_submitting.contains(plan.id)) return;
    _submitting.add(plan.id);
    setState(() {});
    final id = _inFlightIds.putIfAbsent(
      plan.id,
      () => widget.newId?.call() ?? newClientId(),
    );

    try {
      await ref
          .read(maintenanceRecordRepositoryProvider)
          .create(
            _vehicleId,
            MaintenanceRecordDraft(
              id: id,
              occurredOn: CivilDate.todayLocal(),
              kind: MaintenanceRecordKind.performed,
              items: [MaintenanceRecordLineDraft(item: plan.toCatalogueItem())],
            ),
          );
      invalidateAfterMaintenanceWrite(ref, _vehicleId);
      if (!mounted) return;
      setState(() {
        _submitting.remove(plan.id);
        _justRecorded.add(plan.id);
        _inFlightIds.remove(plan.id);
      });
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() => _submitting.remove(plan.id));
      showAppSnackBar(
        ScaffoldMessenger.of(context),
        message: failure.message,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(maintenancePlansProvider(_vehicleId));

    return plans.when(
      skipLoadingOnReload: true,
      loading: () => const _CuidadosSkeleton(),
      error: (error, _) => AppErrorState.fromError(
        error: error,
        onRetry: () => ref.invalidate(maintenancePlansProvider(_vehicleId)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s8,
              AppSpacing.s16,
              AppSpacing.s32,
            ),
            children: [
              _PlansEmpty(
                onCreate: () =>
                    PlanCreateSheet.show(context, vehicleId: _vehicleId),
              ),
              DocumentosSection(vehicleId: _vehicleId),
            ],
          );
        }
        return CuidadosContent(
          plans: list,
          justRecordedIds: _justRecorded,
          submittingIds: _submitting,
          trailing: DocumentosSection(vehicleId: _vehicleId),
          onPlanTap: (plan) => context.push(AppRoutes.plan(plan.id)),
          onBaselineTap: (plan) => context.push(
            AppRoutes.maintenanceNew,
            extra: plan.toCatalogueItem(),
          ),
          onNeedsBaselineGroupTap: () =>
              context.push(AppRoutes.calibrar(_vehicleId)),
          onProfileTap: () => context.push(AppRoutes.vehicleProfile),
          onCreatePlan: () =>
              PlanCreateSheet.show(context, vehicleId: _vehicleId),
          onMarkDone: _markDone,
        );
      },
    );
  }
}

/// Cuidados as pure presentation: grouping and copy, no providers.
///
/// The screen answers "what do I need to do?", and it is built so that the
/// answer is readable in one pass. Groups descend by urgency, **each group is
/// a bounded surface with its label outside it**, and the two groups nobody
/// has to deal with right now — what is on track, and what has already been
/// answered — start collapsed.
///
/// The rows themselves carry no border and no status chip: the group says
/// which list a row is in, the row says the item and its state in one line,
/// and the plan detail has the rest. What the group adds back is an edge —
/// with rows sitting straight on the page, eighteen plans under four labels
/// read as one undifferentiated column, and the labels stopped registering as
/// labels at all.
///
/// "Falta informar" lives here and only here. It used to be on Início as
/// well, where a dozen unanswered items greeted someone who had come to check
/// their car, not to fill in a form.
class CuidadosContent extends StatelessWidget {
  const CuidadosContent({
    super.key,
    required this.plans,
    this.trailing,
    this.onPlanTap,
    this.onBaselineTap,
    this.onNeedsBaselineGroupTap,
    this.onProfileTap,
    this.onCreatePlan,
    this.onMarkDone,
    this.justRecordedIds = const {},
    this.submittingIds = const {},
  });

  final List<MaintenancePlan> plans;
  final Widget? trailing;
  final ValueChanged<MaintenancePlan>? onPlanTap;
  final ValueChanged<MaintenancePlan>? onBaselineTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onNeedsBaselineGroupTap;
  final VoidCallback? onCreatePlan;
  final Future<void> Function(MaintenancePlan plan)? onMarkDone;
  final Set<String> justRecordedIds;
  final Set<String> submittingIds;

  @override
  Widget build(BuildContext context) {
    final groups = groupCuidadosPlans(plans);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s16,
        AppSpacing.s32,
      ),
      children: [
        ..._openGroup(
          title: 'Precisam de atenção',
          plans: groups.needAttention,
          urgent: true,
        ),
        ..._openGroup(title: 'Vencem em breve', plans: groups.dueSoon),
        if (_showEverydayCareEmpty(groups)) ...[
          const _EverydayCareEmpty(),
          const SizedBox(height: appGroupGap),
        ] else
          ..._openGroup(
            title: 'Cuidados do dia a dia',
            plans: groups.everydayCare,
          ),
        ..._openGroup(
          title: 'Falta informar',
          subtitle:
              'O Meu Auto passa a avisar assim que souber quando cada um '
              'foi feito pela última vez.',
          plans: groups.needsBaseline,
          actionLabel: onNeedsBaselineGroupTap == null ? null : 'Informar',
          onAction: onNeedsBaselineGroupTap,
        ),
        if (groups.onTrack.isNotEmpty) ...[
          _CollapsedGroup(
            title: 'Em dia',
            plans: groups.onTrack,
            onTap: _tapOf,
            onMarkDone: onMarkDone,
            justRecordedIds: justRecordedIds,
            submittingIds: submittingIds,
          ),
          const SizedBox(height: appGroupGap),
        ],
        if (groups.historySettled.isNotEmpty) ...[
          _CollapsedGroup(
            title: 'Ainda sem registro',
            explanation:
                'Você já disse que não lembra ou que nunca foi feito. '
                'Quando fizer, registre aqui e a contagem começa.',
            plans: groups.historySettled,
            onTap: _tapOf,
            onMarkDone: onMarkDone,
            justRecordedIds: justRecordedIds,
            submittingIds: submittingIds,
          ),
          const SizedBox(height: appGroupGap),
        ],
        if (groups.historyOnly.isNotEmpty) ...[
          _CollapsedGroup(
            title: 'Só histórico',
            explanation:
                'Esses itens agrupam o que já foi feito e nunca vencem.',
            plans: groups.historyOnly,
            onTap: _tapOf,
            onMarkDone: onMarkDone,
            justRecordedIds: justRecordedIds,
            submittingIds: submittingIds,
          ),
          const SizedBox(height: appGroupGap),
        ],
        if (onCreatePlan != null)
          AppGroup(
            children: [
              AppListRow(
                icon: Icons.add,
                title: 'Acompanhar outro item',
                onTap: onCreatePlan,
                showChevron: true,
              ),
            ],
          ),
        if (trailing != null) ...[
          const SizedBox(height: appGroupGap),
          trailing!,
        ],
        if (onProfileTap != null) ...[
          const SizedBox(height: appGroupGap),
          AppGroup(
            children: [
              AppListRow(
                icon: Icons.tune,
                title: 'O que o seu carro tem',
                subtitle: 'Itens que ele usa, e os que não usa',
                onTap: onProfileTap,
                showChevron: true,
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// One group: a quiet label, then its rows inside one surface.
  ///
  /// Returns the trailing gap with it, so a screen cannot end up with two
  /// groups touching or with a stray gap after an empty one.
  List<Widget> _openGroup({
    required String title,
    required List<MaintenancePlan> plans,
    String? subtitle,
    String? actionLabel,
    VoidCallback? onAction,
    bool urgent = false,
  }) {
    if (plans.isEmpty) return const [];
    return [
      AppGroup(
        title: title,
        subtitle: subtitle,
        actionLabel: actionLabel,
        onAction: onAction,
        count: plans.length > 1 ? plans.length : null,
        children: [
          for (final plan in plans)
            _PlanRow(
              key: ValueKey(plan.id),
              plan: plan,
              urgent: urgent,
              onTap: _tapOf(plan),
              onMarkDone: onMarkDone,
              justRecorded: justRecordedIds.contains(plan.id),
              submitting: submittingIds.contains(plan.id),
            ),
        ],
      ),
      const SizedBox(height: appGroupGap),
    ];
  }

  VoidCallback? _tapOf(MaintenancePlan plan) {
    if (plan.status == MaintenanceStatus.semBaseline &&
        plan.itemKind != MaintenanceItemKind.care) {
      return onBaselineTap == null ? null : () => onBaselineTap!(plan);
    }
    return onPlanTap == null ? null : () => onPlanTap!(plan);
  }
}

bool _showEverydayCareEmpty(CuidadosGroups groups) {
  if (groups.everydayCare.isNotEmpty) return false;
  for (final plan in [...groups.needAttention, ...groups.dueSoon]) {
    if (plan.itemKind == MaintenanceItemKind.care) return false;
  }
  return true;
}

class _EverydayCareEmpty extends StatelessWidget {
  const _EverydayCareEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppGroup(
      title: 'Cuidados do dia a dia',
      children: [
        AppListRowShell(
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tudo em dia', style: theme.textTheme.bodyLarge),
                    Text(
                      'Nenhum cuidado precisa da sua atenção agora.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One plan, as one line.
///
/// [urgent] tints the icon and the state line. It is passed by the group
/// rather than derived from the plan so that colour stays a property of
/// "which list is this" — the thing a person reads first — instead of being
/// sprinkled per row until it means nothing.
class _PlanRow extends StatelessWidget {
  const _PlanRow({
    super.key,
    required this.plan,
    this.urgent = false,
    this.onTap,
    this.onMarkDone,
    this.justRecorded = false,
    this.submitting = false,
  });

  final MaintenancePlan plan;
  final bool urgent;
  final VoidCallback? onTap;
  final Future<void> Function(MaintenancePlan plan)? onMarkDone;
  final bool justRecorded;
  final bool submitting;

  bool get _showDone =>
      showsCareDoneAction(plan) && !justRecorded && onMarkDone != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = statusColors(
      AppStatus.fromWire(plan.status.wire),
      theme.brightness,
    );

    final subtitle = justRecorded
        ? _recordedLine()
        : planListSubtitle(plan);

    return AppListRow(
      icon: maintenanceIconFor(plan.itemSlug),
      title: plan.itemName,
      subtitle: subtitle,
      accent: urgent ? visual.foreground : null,
      onTap: onTap,
      trailing: _showDone
          ? AppButton(
              label: 'Feito',
              loading: submitting,
              onPressed: submitting ? null : () => onMarkDone!(plan),
            )
          : null,
      showChevron: !_showDone && onTap != null,
      semanticLabel: '${plan.itemName}. ${visual.label}. $subtitle',
    );
  }

  /// After a tap on Feito, before the list has come back from the server.
  ///
  /// The next check is the server's own `remaining_days`, so the line is
  /// silent about it when the plan has none rather than inventing one.
  String _recordedLine() {
    final next = careNextCheckPhrase(plan.remainingDays);
    if (next == null) return careRecordedTodayPhrase;
    return '$careRecordedTodayPhrase · $next';
  }
}

/// A group that needs nothing from anyone right now: present, countable,
/// folded.
///
/// Replaces the stock `ExpansionTile`, which brought its own type scale, its
/// own padding and a divider the rest of the screen does not use. The header
/// is the same quiet label every other group has, with a count and a chevron;
/// opening it reveals the same bounded surface the open groups already sit
/// in, so folding something away does not change what it looks like.
class _CollapsedGroup extends StatefulWidget {
  const _CollapsedGroup({
    required this.title,
    required this.plans,
    required this.onTap,
    this.explanation,
    this.onMarkDone,
    this.justRecordedIds = const {},
    this.submittingIds = const {},
  });

  final String title;
  final String? explanation;
  final List<MaintenancePlan> plans;
  final VoidCallback? Function(MaintenancePlan plan) onTap;
  final Future<void> Function(MaintenancePlan plan)? onMarkDone;
  final Set<String> justRecordedIds;
  final Set<String> submittingIds;

  @override
  State<_CollapsedGroup> createState() => _CollapsedGroupState();
}

class _CollapsedGroupState extends State<_CollapsedGroup> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          label: '${widget.title}, ${widget.plans.length} itens',
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _open = !_open),
              borderRadius: AppRadius.borderS,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSpacing.minTapTarget,
                ),
                child: Row(
                  children: [
                    Expanded(
                      // The count earns its place only when there is more
                      // than one thing folded away: "Em dia · 1" is noise
                      // where "Em dia · 12" is the reason not to open it.
                      child: Text(
                        widget.plans.length > 1
                            ? '${widget.title} · ${widget.plans.length}'
                            : widget.title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    Icon(
                      _open ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_open) ...[
          if (widget.explanation != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s8),
              child: Text(
                widget.explanation!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          AppGroup(
            children: [
              for (final plan in widget.plans)
                _PlanRow(
                  key: ValueKey(plan.id),
                  plan: plan,
                  onTap: widget.onTap(plan),
                  onMarkDone: widget.onMarkDone,
                  justRecorded: widget.justRecordedIds.contains(plan.id),
                  submitting: widget.submittingIds.contains(plan.id),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PlansEmpty extends StatelessWidget {
  const _PlansEmpty({this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Os cuidados do seu carro começam aqui',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'O cadastro costuma criar os planos sugeridos. '
            'Você pode criar o primeiro agora.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (onCreate != null) ...[
            const SizedBox(height: AppSpacing.s16),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(label: 'Criar plano', onPressed: onCreate),
            ),
          ],
        ],
      ),
    );
  }
}

class _CuidadosSkeleton extends StatelessWidget {
  const _CuidadosSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s16,
        AppSpacing.s32,
      ),
      children: const [
        AppSkeleton(width: 160, height: 14),
        SizedBox(height: AppSpacing.s16),
        AppSkeletonList(count: 2, itemHeight: 44),
        SizedBox(height: AppSpacing.s32),
        AppSkeleton(width: 140, height: 14),
        SizedBox(height: AppSpacing.s16),
        AppSkeletonList(count: 3, itemHeight: 44),
        SizedBox(height: AppSpacing.s32),
        AppSkeleton(width: 180, height: 14),
        SizedBox(height: AppSpacing.s16),
        AppSkeletonList(count: 3, itemHeight: 44),
      ],
    );
  }
}
