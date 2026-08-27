import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_profile_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_record_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/maintenance/domain/plan_copy.dart';
import 'package:meu_auto/features/maintenance/domain/plan_update.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_icons.dart';
import 'package:meu_auto/features/maintenance/presentation/plan_interval_sheet.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_card.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';
import 'package:meu_auto/shared/widgets/app_status_chip.dart';

class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(selectedVehicleProvider).value;
    if (vehicle == null) {
      return const AppScaffold(title: 'Plano', body: SizedBox.shrink());
    }

    final plans = ref.watch(maintenancePlansProvider(vehicle.id));
    final records = ref.watch(maintenanceRecordsProvider(vehicle.id));

    return plans.when(
      loading: () => const AppScaffold(
        title: 'Plano',
        body: Padding(
          padding: EdgeInsets.all(AppSpacing.s16),
          child: AppSkeletonList(count: 4, itemHeight: 96),
        ),
      ),
      error: (error, _) => AppScaffold(
        title: 'Plano',
        body: AppErrorState.fromError(
          error: error,
          onRetry: () => ref.invalidate(maintenancePlansProvider(vehicle.id)),
        ),
      ),
      data: (list) {
        final plan = _findPlan(list, planId);
        if (plan == null) {
          return AppScaffold(
            title: 'Plano',
            body: AppErrorState(
              message: 'Este plano não está mais ativo.',
              onRetry: () =>
                  ref.invalidate(maintenancePlansProvider(vehicle.id)),
            ),
          );
        }

        final history = _historyOf(records, plan.maintenanceItemId);
        final historyLoading = records.isLoading && records.value == null;

        return AppScaffold(
          title: plan.itemName,
          body: PlanDetailContent(
            plan: plan,
            history: history,
            historyLoading: historyLoading,
            onRegister: () => context.push(
              AppRoutes.maintenanceNew,
              extra: plan.toCatalogueItem(),
            ),
            onAdjustInterval: () => PlanIntervalSheet.show(
              context,
              vehicleId: vehicle.id,
              plan: plan,
            ),
            onKeepHistoryOnly: plan.status == MaintenanceStatus.semPeriodicidade
                ? null
                : () => _clearIntervals(context, ref, vehicle.id, plan),
            onNotApplicable: () =>
                _markNotApplicable(context, ref, vehicle.id, plan),
            onHistoryUnknown: (status) =>
                _setHistory(context, ref, vehicle.id, plan, status),
            onDeactivate: () => _deactivate(context, ref, vehicle.id, plan),
            onOpenRecord: (record) =>
                context.push(AppRoutes.maintenanceRecord(record.id)),
          ),
        );
      },
    );
  }

  List<MaintenanceRecord> _historyOf(
    AsyncValue<PagedState<MaintenanceRecord>> records,
    String itemId,
  ) {
    final page = records.value;
    if (page == null) return const [];
    return historyOfItem(page.items, itemId);
  }
}

MaintenancePlan? _findPlan(List<MaintenancePlan> plans, String id) {
  for (final plan in plans) {
    if (plan.id == id) return plan;
  }
  return null;
}

Future<void> _clearIntervals(
  BuildContext context,
  WidgetRef ref,
  String vehicleId,
  MaintenancePlan plan,
) async {
  final confirmed = await confirmAction(
    context,
    title: 'Guardar só o histórico?',
    message:
        'Este item deixa de vencer. Ele continua agrupando o que você '
        'registrar, mas o Meu Auto não vai mais avisar uma data ou uma '
        'quilometragem.',
    confirmLabel: 'Só guardar histórico',
  );
  if (!confirmed || !context.mounted) return;

  try {
    await ref
        .read(maintenancePlanRepositoryProvider)
        .update(plan.id, const PlanUpdate.clearIntervals());
    invalidateAfterPlanWrite(ref, vehicleId);
    if (!context.mounted) return;
    showAppSnackBar(
      ScaffoldMessenger.of(context),
      message: 'Este item agora só guarda histórico.',
    );
  } on ApiFailure catch (failure) {
    if (!context.mounted) return;
    showAppSnackBar(
      ScaffoldMessenger.of(context),
      message: ApiFormErrors.bannerOf(failure) ?? failure.message,
    );
  }
}

/// "Meu carro não tem isso."
///
/// A correction, not a deletion: the plan stays, keeps its interval and can be
/// brought back from the profile screen. Deactivating would look similar and
/// mean something else — "I do not want to track this" is not "this does not
/// exist on my car", and only the second one should teach the app about the
/// vehicle.
Future<void> _markNotApplicable(
  BuildContext context,
  WidgetRef ref,
  String vehicleId,
  MaintenancePlan plan,
) async {
  final confirmed = await confirmAction(
    context,
    title: 'Seu carro não usa ${plan.itemName.toLowerCase()}?',
    message:
        'Ele sai de todas as listas e não vira lembrete. '
        'Se você mudar de ideia, é só voltar em "O que o seu carro tem".',
    confirmLabel: 'Não usa',
  );
  if (!confirmed || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    await ref
        .read(maintenancePlanRepositoryProvider)
        .update(
          plan.id,
          const PlanUpdate.applicability(
            strategy: MaintenanceStrategy.notApplicable,
          ),
        );
    invalidateAfterProfileWrite(ref, vehicleId);
    navigator.pop();
    showAppSnackBar(messenger, message: '${plan.itemName} saiu da lista.');
  } on ApiFailure catch (failure) {
    if (!context.mounted) return;
    showAppSnackBar(
      messenger,
      message: ApiFormErrors.bannerOf(failure) ?? failure.message,
    );
  }
}

/// "Não sei" and "nunca foi feito", recorded as what they are.
///
/// Neither writes a maintenance record. A record asserts a date and a mileage,
/// and both of these answers exist precisely because the owner does not have
/// them — inventing one would put a fabricated fact into the history whose whole
/// value is being trustworthy.
Future<void> _setHistory(
  BuildContext context,
  WidgetRef ref,
  String vehicleId,
  MaintenancePlan plan,
  MaintenanceHistoryStatus status,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(maintenancePlanRepositoryProvider)
        .update(plan.id, PlanUpdate.history(status));
    invalidateAfterProfileWrite(ref, vehicleId);
    showAppSnackBar(
      messenger,
      message: status == MaintenanceHistoryStatus.never
          ? 'Anotado: nunca foi feito.'
          : 'Tudo bem. Não vamos perguntar de novo.',
    );
  } on ApiFailure catch (failure) {
    if (!context.mounted) return;
    showAppSnackBar(
      messenger,
      message: ApiFormErrors.bannerOf(failure) ?? failure.message,
    );
  }
}

Future<void> _deactivate(
  BuildContext context,
  WidgetRef ref,
  String vehicleId,
  MaintenancePlan plan,
) async {
  final confirmed = await confirmAction(
    context,
    title: 'Desativar este plano?',
    message:
        'Ele sai da lista de cuidados, mas o histórico deste item '
        'permanece. Dá para criar de novo depois.',
    confirmLabel: 'Desativar',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    await ref.read(maintenancePlanRepositoryProvider).deactivate(plan.id);
    invalidateAfterPlanWrite(ref, vehicleId);
    navigator.pop();
    showAppSnackBar(messenger, message: 'Plano desativado.');
  } on ApiFailure catch (failure) {
    showAppSnackBar(
      messenger,
      message: ApiFormErrors.bannerOf(failure) ?? failure.message,
    );
  }
}

class PlanDetailContent extends StatelessWidget {
  const PlanDetailContent({
    super.key,
    required this.plan,
    this.history = const [],
    this.historyLoading = false,
    this.onRegister,
    this.onAdjustInterval,
    this.onKeepHistoryOnly,
    this.onNotApplicable,
    this.onHistoryUnknown,
    this.onDeactivate,
    this.onOpenRecord,
  });

  final MaintenancePlan plan;
  final List<MaintenanceRecord> history;
  final bool historyLoading;
  final VoidCallback? onRegister;
  final VoidCallback? onAdjustInterval;
  final VoidCallback? onKeepHistoryOnly;

  /// "Meu carro não tem isso."
  final VoidCallback? onNotApplicable;

  /// "Não sei" / "nunca foi feito". Only offered while there is no baseline —
  /// once a service is recorded, the record is the answer.
  final ValueChanged<MaintenanceHistoryStatus>? onHistoryUnknown;

  final VoidCallback? onDeactivate;
  final ValueChanged<MaintenanceRecord>? onOpenRecord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phrase = planStatusPhrase(plan);
    final last = lastDonePhrase(
      occurredOn: plan.lastOccurredOn,
      mileageKm: plan.lastMileageKm,
    );
    final next = dueNextPhrase(dueAtKm: plan.dueAtKm, dueOn: plan.dueOn);
    final interval = intervalPhrase(
      km: plan.intervalKm,
      months: plan.intervalMonths,
      days: plan.intervalDays,
    );
    final howItWorks = strategyExplanation(plan);
    // One rule, one place. The two answers about the past make sense only while
    // there is nothing to measure from AND nobody has answered yet: once a
    // service is recorded the record IS the answer, and once somebody has said
    // "não sei" asking again is the nagging this change exists to remove.
    final canAnswerHistory =
        onHistoryUnknown != null &&
        plan.status == MaintenanceStatus.semBaseline &&
        plan.historyStatus == MaintenanceHistoryStatus.notAsked;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              maintenanceIconFor(plan.itemSlug),
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s4,
                children: [
                  AppStatusChip(status: AppStatus.fromWire(plan.status.wire)),
                  if (phrase.isNotEmpty)
                    Text(phrase, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s24),
        const AppSectionHeader(title: 'Última vez'),
        const SizedBox(height: AppSpacing.s8),
        AppCard(
          onTap: last == null ? onRegister : null,
          child: Text(
            last ?? 'Informe a última vez para começarmos a contar',
            style: theme.textTheme.bodyLarge,
          ),
        ),
        if (next != null) ...[
          const SizedBox(height: AppSpacing.s24),
          const AppSectionHeader(title: 'Próxima'),
          const SizedBox(height: AppSpacing.s8),
          AppCard(child: Text(next, style: theme.textTheme.bodyLarge)),
        ],
        if (interval != null) ...[
          const SizedBox(height: AppSpacing.s24),
          const AppSectionHeader(title: 'Intervalo'),
          const SizedBox(height: AppSpacing.s8),
          AppCard(child: Text(interval, style: theme.textTheme.bodyLarge)),
        ],
        if (howItWorks != null) ...[
          const SizedBox(height: AppSpacing.s8),
          Text(
            howItWorks,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (plan.notes != null) ...[
          const SizedBox(height: AppSpacing.s8),
          Text(
            plan.notes!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s24),
        const AppSectionHeader(title: 'Histórico deste item'),
        const SizedBox(height: AppSpacing.s8),
        if (historyLoading)
          const AppSkeleton(width: double.infinity, height: 72)
        else if (history.isEmpty)
          AppCard(
            child: Text(
              'Ainda não há serviço deste item. O primeiro registro começa o histórico.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (var i = 0; i < history.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.s8),
            _HistoryTile(
              record: history[i],
              previous: i + 1 < history.length ? history[i + 1] : null,
              onTap: onOpenRecord == null
                  ? null
                  : () => onOpenRecord!(history[i]),
            ),
          ],
        const SizedBox(height: AppSpacing.s24),
        AppButton(label: 'Registrar agora', onPressed: onRegister),
        const SizedBox(height: AppSpacing.s8),
        AppButton(
          label: 'Ajustar intervalo',
          variant: AppButtonVariant.secondary,
          onPressed: onAdjustInterval,
        ),
        // Offered before the destructive options, because it is the honest
        // answer far more often than "desativar": most people who do not want a
        // reminder do not have the part.
        if (canAnswerHistory) ...[
          const SizedBox(height: AppSpacing.s8),
          TextButton(
            onPressed: () =>
                onHistoryUnknown!(MaintenanceHistoryStatus.unknown),
            child: const Text('Não sei quando foi'),
          ),
          TextButton(
            onPressed: () => onHistoryUnknown!(MaintenanceHistoryStatus.never),
            child: const Text('Nunca foi feito'),
          ),
        ],
        if (onKeepHistoryOnly != null) ...[
          const SizedBox(height: AppSpacing.s8),
          TextButton(
            onPressed: onKeepHistoryOnly,
            child: const Text('Só quero guardar o histórico'),
          ),
        ],
        if (onNotApplicable != null)
          TextButton(
            onPressed: onNotApplicable,
            child: const Text('Meu carro não usa isso'),
          ),
        const SizedBox(height: AppSpacing.s8),
        AppButton(
          label: 'Desativar plano',
          variant: AppButtonVariant.destructive,
          onPressed: onDeactivate,
        ),
        if (plan.origin == MaintenancePlanOrigin.suggested) ...[
          const SizedBox(height: AppSpacing.s16),
          Text(
            'Se você alterar este plano, ele deixa de seguir os padrões '
            'sugeridos e passa a ser só o seu.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record, this.previous, this.onTap});

  final MaintenanceRecord record;
  final MaintenanceRecord? previous;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previousRecord = previous;
    final delta = previousRecord == null
        ? null
        : mileageSincePreviousPhrase(
            record.mileageKm,
            previousRecord.mileageKm,
          );

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${formatCivilDateLong(record.occurredOn)} · ${formatKm(record.mileageKm)}',
            style: theme.textTheme.titleSmall,
          ),
          if (delta != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(
              delta,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
