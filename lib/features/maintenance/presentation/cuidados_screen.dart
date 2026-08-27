import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/client_id.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/router/app_routes.dart';
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
import 'package:meu_auto/shared/widgets/app_card.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';
import 'package:meu_auto/shared/widgets/app_status_chip.dart';

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
            label: 'Seu carro',
            icon: Icons.tune,
            onPressed: () => context.push(AppRoutes.vehicleProfile),
          ),
        if (vehicle != null)
          AppIconButton(
            label: 'Criar plano',
            icon: Icons.add,
            onPressed: () =>
                PlanCreateSheet.show(context, vehicleId: vehicle.id),
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
            padding: const EdgeInsets.all(AppSpacing.s16),
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
          onMarkDone: _markDone,
        );
      },
    );
  }
}

/// The Cuidados tab as pure presentation: grouping and copy, no providers.
class CuidadosContent extends StatelessWidget {
  const CuidadosContent({
    super.key,
    required this.plans,
    this.trailing,
    this.onPlanTap,
    this.onBaselineTap,
    this.onNeedsBaselineGroupTap,
    this.onProfileTap,
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
  final Future<void> Function(MaintenancePlan plan)? onMarkDone;
  final Set<String> justRecordedIds;
  final Set<String> submittingIds;

  @override
  Widget build(BuildContext context) {
    final groups = groupCuidadosPlans(plans);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        ..._openGroup(
          context,
          title: 'Precisam de atenção',
          plans: groups.needAttention,
        ),
        ..._openGroup(context, title: 'Vencem em breve', plans: groups.dueSoon),
        if (_showEverydayCareEmpty(groups)) ...[
          const _EverydayCareEmpty(),
        ] else ..._openGroup(
          context,
          title: 'Cuidados do dia a dia',
          plans: groups.everydayCare,
        ),
        if (groups.onTrack.isNotEmpty)
          _CollapsedGroup(
            title: 'Em dia',
            plans: groups.onTrack,
            onTap: _tapOf,
            onMarkDone: onMarkDone,
            justRecordedIds: justRecordedIds,
            submittingIds: submittingIds,
          ),
        ..._openGroup(
          context,
          title: 'Falta informar',
          plans: groups.needsBaseline,
          actionLabel: onNeedsBaselineGroupTap == null ? null : 'Informar',
          onAction: onNeedsBaselineGroupTap,
        ),
        if (groups.historySettled.isNotEmpty)
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
        if (groups.historyOnly.isNotEmpty)
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
        ?trailing,
        if (onProfileTap != null) ...[
          const SizedBox(height: AppSpacing.s16),
          _ProfileLink(onTap: onProfileTap!),
        ],
      ],
    );
  }

  List<Widget> _openGroup(
    BuildContext context, {
    required String title,
    required List<MaintenancePlan> plans,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (plans.isEmpty) return const [];
    return [
      AppSectionHeader(
        title: title,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
      const SizedBox(height: AppSpacing.s8),
      for (final plan in plans) ...[
        _PlanTile(
          key: ValueKey(plan.id),
          plan: plan,
          onTap: _tapOf(plan),
          onMarkDone: onMarkDone,
          justRecorded: justRecordedIds.contains(plan.id),
          submitting: submittingIds.contains(plan.id),
        ),
        const SizedBox(height: AppSpacing.s8),
      ],
      const SizedBox(height: AppSpacing.s8),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(title: 'Cuidados do dia a dia'),
          const SizedBox(height: AppSpacing.s8),
          Text('Tudo em dia', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Nenhum cuidado precisa da sua atenção agora.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    super.key,
    required this.plan,
    this.onTap,
    this.onMarkDone,
    this.justRecorded = false,
    this.submitting = false,
  });

  final MaintenancePlan plan;
  final VoidCallback? onTap;
  final Future<void> Function(MaintenancePlan plan)? onMarkDone;
  final bool justRecorded;
  final bool submitting;

  bool get _showDone =>
      showsCareDoneAction(plan) && !justRecorded && onMarkDone != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phrase = planStatusPhrase(plan);
    final nextCheck = careNextCheckPhrase(plan.remainingDays);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final label = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            maintenanceIconFor(plan.itemSlug),
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.itemName, style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.s4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s4,
                    children: [
                      AppStatusChip(
                        status: AppStatus.fromWire(plan.status.wire),
                      ),
                      if (phrase.isNotEmpty) Text(phrase, style: muted),
                    ],
                  ),
                  if (justRecorded) ...[
                    const SizedBox(height: AppSpacing.s8),
                    Text(careRecordedTodayPhrase, style: muted),
                    if (nextCheck != null) Text(nextCheck, style: muted),
                  ] else if (plan.itemKind == MaintenanceItemKind.care) ...[
                    if (plan.lastOccurredOn != null) ...[
                      const SizedBox(height: AppSpacing.s8),
                      Text('Última verificação', style: label),
                      Text(
                        formatCivilDateLong(plan.lastOccurredOn!),
                        style: muted,
                      ),
                    ],
                    if (plan.dueOn != null) ...[
                      const SizedBox(height: AppSpacing.s8),
                      Text('Próxima', style: label),
                      Text(formatCivilDateLong(plan.dueOn!), style: muted),
                    ],
                  ],
                ],
              ),
            ),
          ),
          if (_showDone) ...[
            const SizedBox(width: AppSpacing.s8),
            AppButton(
              label: 'Feito',
              loading: submitting,
              onPressed: submitting ? null : () => onMarkDone!(plan),
            ),
          ],
        ],
      ),
    );
  }
}

class _CollapsedGroup extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        initiallyExpanded: false,
        title: Text(title, style: theme.textTheme.titleMedium),
        children: [
          if (explanation != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                explanation!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
          for (final plan in plans) ...[
            _PlanTile(
              key: ValueKey(plan.id),
              plan: plan,
              onTap: onTap(plan),
              onMarkDone: onMarkDone,
              justRecorded: justRecordedIds.contains(plan.id),
              submitting: submittingIds.contains(plan.id),
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
        ],
      ),
    );
  }
}

/// The way back to what this car has and does not have.
///
/// Quiet, and at the bottom. The list above is already personalised; this is for
/// the person who wants to know why something is missing, or to tell us we got
/// it wrong.
class _ProfileLink extends StatelessWidget {
  const _ProfileLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(Icons.tune, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              'O que o seu carro tem',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
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
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: const [
        AppSkeleton(width: 180, height: 24),
        SizedBox(height: AppSpacing.s12),
        AppSkeletonList(count: 2, itemHeight: 88),
        SizedBox(height: AppSpacing.s24),
        AppSkeleton(width: 160, height: 24),
        SizedBox(height: AppSpacing.s12),
        AppSkeletonList(count: 2, itemHeight: 88),
        SizedBox(height: AppSpacing.s24),
        AppSkeleton(width: 200, height: 24),
        SizedBox(height: AppSpacing.s12),
        AppSkeletonList(count: 3, itemHeight: 88),
      ],
    );
  }
}
