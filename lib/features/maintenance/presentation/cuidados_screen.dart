import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/features/maintenance/domain/cuidados_groups.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/plan_copy.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_icons.dart';
import 'package:meu_auto/features/maintenance/presentation/plan_create_sheet.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_card.dart';
import 'package:meu_auto/shared/widgets/app_empty_state.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
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
    try {
      await ref.read(maintenancePlansProvider(vehicleId).future);
    } on Object {
      // The provider already holds the failure; CuidadosView renders it.
    }
  }
}

class CuidadosView extends ConsumerWidget {
  const CuidadosView({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(maintenancePlansProvider(vehicleId));

    return plans.when(
      loading: () => const _CuidadosSkeleton(),
      error: (error, _) => AppErrorState.fromError(
        error: error,
        onRetry: () => ref.invalidate(maintenancePlansProvider(vehicleId)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return AppEmptyState(
            title: 'Os cuidados do seu carro começam aqui',
            message:
                'O cadastro costuma criar os planos sugeridos. '
                'Você pode criar o primeiro agora.',
            actionLabel: 'Criar plano',
            onAction: () => PlanCreateSheet.show(context, vehicleId: vehicleId),
          );
        }
        return CuidadosContent(
          plans: list,
          onPlanTap: (plan) => context.push(AppRoutes.plan(plan.id)),
          onBaselineTap: (plan) => context.push(
            AppRoutes.maintenanceNew,
            extra: plan.toCatalogueItem(),
          ),
          onNeedsBaselineGroupTap: () =>
              context.push(AppRoutes.calibrar(vehicleId)),
          onProfileTap: () => context.push(AppRoutes.vehicleProfile),
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
    this.onPlanTap,
    this.onBaselineTap,
    this.onNeedsBaselineGroupTap,
    this.onProfileTap,
  });

  final List<MaintenancePlan> plans;
  final ValueChanged<MaintenancePlan>? onPlanTap;
  final ValueChanged<MaintenancePlan>? onBaselineTap;
  final VoidCallback? onNeedsBaselineGroupTap;
  final VoidCallback? onProfileTap;

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
        ..._openGroup(
          context,
          title: 'Cuidados do dia a dia',
          plans: groups.everydayCare,
        ),
        if (groups.onTrack.isNotEmpty)
          _CollapsedGroup(
            title: 'Em dia',
            plans: groups.onTrack,
            onTap: _tapOf,
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
          ),
        if (groups.historyOnly.isNotEmpty)
          _CollapsedGroup(
            title: 'Só histórico',
            explanation:
                'Esses itens agrupam o que já foi feito e nunca vencem.',
            plans: groups.historyOnly,
            onTap: _tapOf,
          ),
        if (onProfileTap != null) ...[
          const SizedBox(height: AppSpacing.s16),
          _ProfileLink(onTap: onProfileTap!),
        ],
        const _DocumentosNotBuilt(),
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
        _PlanTile(plan: plan, onTap: _tapOf(plan)),
        const SizedBox(height: AppSpacing.s8),
      ],
      const SizedBox(height: AppSpacing.s8),
    ];
  }

  VoidCallback? _tapOf(MaintenancePlan plan) {
    if (plan.status == MaintenanceStatus.semBaseline) {
      return onBaselineTap == null ? null : () => onBaselineTap!(plan);
    }
    return onPlanTap == null ? null : () => onPlanTap!(plan);
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan, this.onTap});

  final MaintenancePlan plan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phrase = planStatusPhrase(plan);

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            maintenanceIconFor(plan.itemSlug),
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
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
                    AppStatusChip(status: AppStatus.fromWire(plan.status.wire)),
                    if (phrase.isNotEmpty)
                      Text(
                        phrase,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
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
  });

  final String title;
  final String? explanation;
  final List<MaintenancePlan> plans;
  final VoidCallback? Function(MaintenancePlan plan) onTap;

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
            _PlanTile(plan: plan, onTap: onTap(plan)),
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

/// Says out loud that ipva, licenciamento and seguro have no screens yet.
///
/// The server has the routes; this app does not consume them. Saying so beats
/// hiding the gap, and it certainly beats showing invented figures. Delete
/// this when the screens land — see docs/DECISOES-EM-ABERTO.md.
class _DocumentosNotBuilt extends StatelessWidget {
  const _DocumentosNotBuilt();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.s24,
        bottom: AppSpacing.s16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              'IPVA, licenciamento e seguro entram em breve.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
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
