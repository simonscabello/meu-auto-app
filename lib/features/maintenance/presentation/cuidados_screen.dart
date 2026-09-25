import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/client_id.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_item_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_profile_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_record_provider.dart';
import 'package:meu_auto/features/maintenance/domain/cuidados_groups.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_profile.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record_draft.dart';
import 'package:meu_auto/features/maintenance/domain/plan_copy.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_icons.dart';
import 'package:meu_auto/features/maintenance/presentation/plan_create_sheet.dart';
import 'package:meu_auto/features/maintenance/presentation/vehicle_profile_screen.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/presentation/vehicle_context_title.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_empty_state.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_expandable_group.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_group_scope.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

class CuidadosScreen extends ConsumerWidget {
  const CuidadosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedVehicleProvider);
    final vehicle = selected.valueOrNull;

    return AppScaffold(
      onRefresh: vehicle == null ? null : () => _refresh(ref, vehicle.id),
      body: Column(
        children: [
          VehicleTabHeader(
            title: 'Manutenção',
            actions: [
              if (vehicle != null)
                AppIconButton(
                  label: 'Registrar manutenção',
                  icon: Icons.add,
                  onPressed: () => context.push(AppRoutes.maintenanceNew),
                ),
            ],
          ),
          Expanded(
            child: selected.when(
              loading: () => const _CuidadosSkeleton(),
              error: (error, _) => AppErrorState.fromError(
                error: error,
                onRetry: () => ref.read(vehiclesProvider.notifier).reload(),
              ),
              data: (current) => current == null
                  ? const SizedBox.shrink()
                  : CuidadosView(vehicleId: current.id),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref, String vehicleId) async {
    ref.invalidate(maintenancePlansProvider(vehicleId));
    ref.invalidate(maintenanceProfileProvider(vehicleId));
    try {
      await ref.read(maintenancePlansProvider(vehicleId).future);
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

    final repository = ref.read(maintenanceRecordRepositoryProvider);
    try {
      final created = await repository.create(
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
      // One tap writes a record, so one tap takes it back: a "Feito" hit by
      // accident on the wrong row used to leave a false entry in the history
      // with no way out but finding it there and deleting it.
      showAppSnackBar(
        ScaffoldMessenger.of(context),
        message: '${plan.itemName}: registrado hoje.',
        onUndo: () => unawaited(_undoDone(plan, created.id)),
      );
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() => _submitting.remove(plan.id));
      showAppSnackBar(ScaffoldMessenger.of(context), message: failure.message);
    }
  }

  Future<void> _undoDone(MaintenancePlan plan, String recordId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(maintenanceRecordRepositoryProvider).delete(recordId);
      invalidateAfterMaintenanceWrite(ref, _vehicleId);
      if (!mounted) return;
      setState(() => _justRecorded.remove(plan.id));
    } on ApiFailure catch (failure) {
      showAppErrorSnackBar(messenger, message: failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(maintenancePlansProvider(_vehicleId));
    final question = ref
        .watch(maintenanceProfileProvider(_vehicleId))
        .valueOrNull
        ?.questions
        .firstOrNull;

    return plans.when(
      skipLoadingOnReload: true,
      loading: () => const _CuidadosSkeleton(),
      error: (error, _) => AppErrorState.fromError(
        error: error,
        onRetry: () => ref.invalidate(maintenancePlansProvider(_vehicleId)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return AppEmptyState(
            icon: Icons.build_outlined,
            title: 'Os cuidados do seu carro começam aqui',
            message:
                'O cadastro costuma criar os planos sugeridos. '
                'Você pode criar o primeiro agora.',
            actionLabel: 'Criar plano',
            onAction: () =>
                PlanCreateSheet.show(context, vehicleId: _vehicleId),
          );
        }
        return CuidadosContent(
          plans: list,
          openQuestion: question,
          onAnswer: (questionId, answer) => unawaited(
            answerProfileQuestion(context, ref, _vehicleId, questionId, answer),
          ),
          justRecordedIds: _justRecorded,
          submittingIds: _submitting,
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
/// The rows carry no status chip: the group says which list a row is in, the
/// row says the item and its state in one line, and the well is tinted only
/// on the rows that are actually late or close.
class CuidadosContent extends StatelessWidget {
  const CuidadosContent({
    super.key,
    required this.plans,
    this.openQuestion,
    this.onAnswer,
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
  final MaintenanceProfileQuestion? openQuestion;
  final void Function(String questionId, String answer)? onAnswer;
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
      padding: AppSpacing.tab,
      children: [
        if (openQuestion != null) ...[
          const AppSectionHeader(title: 'Uma pergunta sobre o seu carro'),
          ProfileQuestionCard(
            question: openQuestion!,
            onAnswer: onAnswer == null
                ? null
                : (answer) => onAnswer!(openQuestion!.id, answer),
          ),
          const SizedBox(height: appGroupGap),
        ],
        ..._openGroup(
          title: 'Vencidos',
          plans: groups.needAttention,
          urgent: true,
        ),
        ..._openGroup(
          title: 'Vencem em breve',
          plans: groups.dueSoon,
          urgent: true,
        ),
        if (_showEverydayCareEmpty(groups)) ...[
          const _EverydayCareEmpty(),
          const SizedBox(height: appGroupGap),
        ] else
          ..._openGroup(
            title: 'Cuidados do dia a dia',
            plans: groups.everydayCare,
          ),
        ..._openGroup(
          title: 'Sem data da última vez',
          subtitle: 'Sem a data da última vez, não há como avisar.',
          plans: [...groups.needsBaseline, ...groups.historySettled],
          actionLabel:
              onNeedsBaselineGroupTap == null || groups.needsBaseline.isEmpty
              ? null
              : 'Informar',
          onAction: onNeedsBaselineGroupTap,
        ),
        if (groups.onTrack.isNotEmpty) ...[
          AppExpandableGroup(
            title: 'Em dia',
            count: groups.onTrack.length,
            children: [for (final plan in groups.onTrack) _row(plan)],
          ),
          const SizedBox(height: AppSpacing.s12),
        ],
        if (groups.historyOnly.isNotEmpty) ...[
          AppExpandableGroup(
            title: 'Só histórico',
            count: groups.historyOnly.length,
            explanation: 'Ficam no histórico e nunca vencem.',
            children: [for (final plan in groups.historyOnly) _row(plan)],
          ),
          const SizedBox(height: AppSpacing.s12),
        ],
        const SizedBox(height: AppSpacing.s16),
        AppGroup(
          title: 'Seu plano',
          children: [
            if (onCreatePlan != null)
              AppListRow(
                icon: Icons.add,
                iconTone: AppIconWellTone.accent,
                title: 'Acompanhar outro item',
                onTap: onCreatePlan,
                showChevron: true,
              ),
            if (onProfileTap != null)
              AppListRow(
                icon: Icons.tune_outlined,
                title: 'O que o seu carro tem',
                subtitle: 'Itens que ele usa, e os que não usa',
                onTap: onProfileTap,
                showChevron: true,
              ),
          ],
        ),
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

  Widget _row(MaintenancePlan plan) {
    return _PlanRow(
      key: ValueKey(plan.id),
      plan: plan,
      onTap: _tapOf(plan),
      onMarkDone: onMarkDone,
      justRecorded: justRecordedIds.contains(plan.id),
      submitting: submittingIds.contains(plan.id),
    );
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
    return const AppGroup(
      title: 'Cuidados do dia a dia',
      children: [
        AppListRow(
          icon: Icons.check_circle_outline,
          iconTone: AppIconWellTone.accent,
          title: 'Tudo em dia',
          subtitle: 'Nenhum cuidado para agora',
        ),
      ],
    );
  }
}

/// One plan, as one line.
///
/// [urgent] tints the well and the state line with the plan's own status.
/// It is passed by the group rather than derived from the plan so that
/// colour stays a property of "which list is this" — the thing a person
/// reads first — instead of being sprinkled per row until it means nothing.
class _PlanRow extends StatelessWidget with GroupedRow {
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
    final status = AppStatus.fromWire(plan.status.wire);
    final visual = statusColors(status, theme.brightness);
    final subtitle = justRecorded ? _recordedLine() : planListSubtitle(plan);

    return AppListRow(
      icon: maintenanceIconFor(plan.itemSlug),
      title: plan.itemName,
      subtitle: subtitle,
      status: urgent && !justRecorded ? status : null,
      onTap: onTap,
      // Tonal and short, not filled: a list of habits can carry three or four
      // of these at once, and a column of accent buttons outshouted the
      // overdue items above them. The row's own words say what is due.
      trailing: _showDone
          ? AppButton(
              label: 'Feito',
              variant: AppButtonVariant.secondary,
              compact: true,
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

class _CuidadosSkeleton extends StatelessWidget {
  const _CuidadosSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.screen,
      children: const [
        AppSkeleton(width: 160, height: 14),
        SizedBox(height: AppSpacing.s12),
        AppSkeleton(width: double.infinity, height: 124),
        SizedBox(height: AppSpacing.block),
        AppSkeleton(width: 140, height: 14),
        SizedBox(height: AppSpacing.s12),
        AppSkeleton(width: double.infinity, height: 186),
        SizedBox(height: AppSpacing.block),
        AppSkeleton(width: 180, height: 14),
        SizedBox(height: AppSpacing.s12),
        AppSkeleton(width: double.infinity, height: 186),
      ],
    );
  }
}
