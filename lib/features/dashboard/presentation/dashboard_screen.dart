import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/domain/phrases.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/features/dashboard/application/dashboard_provider.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_profile.dart';
import 'package:meu_auto/features/odometer/presentation/odometer_sheet.dart';
import 'package:meu_auto/shared/widgets/app_card.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_metric.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_status_chip.dart';

/// Início, for one vehicle. Owns the loading, error and content states and
/// hands the data to [DashboardContent], which knows nothing about providers.
class DashboardView extends ConsumerWidget {
  const DashboardView({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider(vehicleId));

    return dashboard.when(
      loading: () => const _DashboardSkeleton(),
      error: (error, _) => AppErrorState.fromError(
        error: error,
        onRetry: () => ref.invalidate(dashboardProvider(vehicleId)),
      ),
      data: (data) => DashboardContent(
        dashboard: data,
        onOdometerTap: () => OdometerSheet.show(
          context,
          vehicleId: vehicleId,
          currentMileageKm: data.odometer.currentKm,
        ),
        onConfigureTap: () => context.push(AppRoutes.calibrar(vehicleId)),
        onProfileTap: () => context.push(AppRoutes.vehicleProfile),
        onSeeAllAlerts: () => context.go(AppRoutes.care),
        onAlertTap: (alert) => _openAlert(context, alert),
        onCostsTap: () => context.push(AppRoutes.costs),
      ),
    );
  }

  /// `reference_type` says where an alert lives. Obligations and seguros
  /// still land on Cuidados until Prompt 17 fills that section.
  void _openAlert(BuildContext context, Alert alert) {
    switch (alert.referenceType) {
      case AlertReferenceType.maintenanceRecord:
        context.push(AppRoutes.maintenanceRecord(alert.referenceId));
      case AlertReferenceType.maintenancePlan:
        context.push(AppRoutes.plan(alert.referenceId));
      case AlertReferenceType.obligation:
      case AlertReferenceType.seguro:
      case AlertReferenceType.desconhecido:
        context.go(AppRoutes.care);
    }
  }
}

/// The dashboard as pure presentation.
///
/// Every number here arrived computed by the server — `overdue`, `due_soon`,
/// `remaining_km`, `remaining_days`, `tracked_cents`. Nothing in this file
/// derives a due date, a status or a total; it turns figures into sentences.
class DashboardContent extends StatelessWidget {
  const DashboardContent({
    super.key,
    required this.dashboard,
    this.onOdometerTap,
    this.onConfigureTap,
    this.onProfileTap,
    this.onSeeAllAlerts,
    this.onAlertTap,
    this.onCostsTap,
  });

  final Dashboard dashboard;
  final VoidCallback? onOdometerTap;
  final VoidCallback? onConfigureTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onSeeAllAlerts;
  final ValueChanged<Alert>? onAlertTap;
  final VoidCallback? onCostsTap;

  @override
  Widget build(BuildContext context) {
    final alerts = dashboard.alerts;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        // The question this screen exists to answer goes first. The odometer
        // is the supporting fact, not the headline: someone opening the app
        // wants to know whether the car is fine before they read a number.
        _StatusBanner(status: statusOf(alerts), phrase: statusPhraseOf(alerts)),
        const SizedBox(height: AppSpacing.s12),
        _OdometerCard(
          odometer: dashboard.odometer,
          plate: dashboard.vehicle.plate,
          onTap: onOdometerTap,
        ),
        if (alerts.items.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s24),
          AppSectionHeader(
            title: 'Próximos cuidados',
            actionLabel: onSeeAllAlerts == null ? null : 'Ver todos',
            onAction: onSeeAllAlerts,
          ),
          const SizedBox(height: AppSpacing.s8),
          for (final alert in alerts.items) ...[
            _AlertTile(
              alert: alert,
              onTap: onAlertTap == null ? null : () => onAlertTap!(alert),
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
        ],
        if (alerts.needsBaseline > 0) ...[
          const SizedBox(height: AppSpacing.s16),
          _SetupCard(count: alerts.needsBaseline, onTap: onConfigureTap),
        ],
        if (profilePromptOf(dashboard.profile) != null) ...[
          const SizedBox(height: AppSpacing.s16),
          _ProfileCard(
            message: profilePromptOf(dashboard.profile)!,
            onTap: onProfileTap,
          ),
        ],
        const SizedBox(height: AppSpacing.s24),
        _CostsCard(costs: dashboard.costs, onTap: onCostsTap),
      ],
    );
  }
}

// ---------------------------------------------------------------- copy

/// The one sentence that answers "is my car OK?".
///
/// Priority order, and only one shows: something is late, something is close,
/// something needs setting up, everything is fine.
@visibleForTesting
String statusPhraseOf(DashboardAlerts alerts) {
  if (alerts.overdue > 0) {
    return alerts.overdue == 1
        ? '1 item precisa de atenção'
        : '${alerts.overdue} itens precisam de atenção';
  }
  if (alerts.dueSoon > 0) {
    return alerts.dueSoon == 1
        ? '1 item vence em breve'
        : '${alerts.dueSoon} itens vencem em breve';
  }
  if (alerts.needsBaseline > 0) {
    return 'Falta informar o histórico';
  }
  return 'Tudo em dia';
}

/// `sem_baseline` is deliberately not an alert colour: a brand new vehicle has
/// roughly eighteen of them and none of them is a problem.
@visibleForTesting
AppStatus statusOf(DashboardAlerts alerts) {
  if (alerts.overdue > 0) return AppStatus.vencido;
  if (alerts.dueSoon > 0) return AppStatus.venceEmBreve;
  if (alerts.needsBaseline > 0) return AppStatus.semBaseline;
  return AppStatus.emDia;
}

/// The discreet line about what we still do not know about the car.
///
/// Null most of the time, and that is the design: it appears when there is
/// genuinely something to ask, and disappears the moment it is answered —
/// including when the answer is "não sei". A prompt that never goes away is
/// noise, and this one has a real ending.
///
/// It never explains the model. "Aplicabilidade", "estratégia" and
/// "não se aplica" are words for the schema, not for the person holding the
/// phone.
@visibleForTesting
String? profilePromptOf(DashboardProfile profile) {
  if (!profile.powertrainKnown) {
    return 'Falta dizer qual o combustível do seu carro. '
        'Com isso a gente sabe o que ele precisa — e o que não precisa.';
  }
  if (profile.openQuestions == 1) {
    return 'Falta 1 informação sobre o seu carro.';
  }
  if (profile.openQuestions > 1) {
    return 'Faltam ${profile.openQuestions} informações sobre o seu carro.';
  }
  if (profile.status == MaintenanceProfileStatus.unknown) {
    return 'Ainda não temos um plano para este carro. '
        'Você escolhe o que quer acompanhar.';
  }
  return null;
}

/// `cost_months` is a rolling window measured back from `since`, not a calendar
/// month. Calling one month "este mês" would be wrong on every day but the 1st.
@visibleForTesting
String costPeriodLabel(int periodMonths) {
  if (periodMonths == 1) {
    return 'Custo registrado · últimos 30 dias';
  }
  return 'Custo registrado · últimos $periodMonths meses';
}

const _categoryLabels = {
  'manutencao': 'manutenção',
  'ipva': 'IPVA',
  'licenciamento': 'licenciamento',
  'seguro': 'seguro',
  'abastecimento': 'combustível',
  'expenses': 'despesas',
};

/// Spells out what the total actually covers.
///
/// Required by the contract, and by honesty: without fuel and day-to-day
/// expenses this figure is a partial sum, and presenting it as the cost of
/// running the car would be a lie. An unmapped category is shown raw rather
/// than dropped, so a category added later still appears.
@visibleForTesting
String? includedCategoriesLine(List<String> categories) {
  if (categories.isEmpty) return null;
  final labels = [
    for (final category in categories) _categoryLabels[category] ?? category,
  ];
  if (labels.length == 1) return 'Inclui ${labels.single}';
  final head = labels.sublist(0, labels.length - 1).join(', ');
  return 'Inclui $head e ${labels.last}';
}

IconData _alertIcon(AlertKind kind) {
  return switch (kind) {
    AlertKind.manutencao => Icons.build,
    AlertKind.cuidado => Icons.checklist,
    AlertKind.garantia => Icons.verified_user,
    AlertKind.ipva => Icons.receipt_long,
    AlertKind.licenciamento => Icons.description,
    AlertKind.seguro => Icons.shield_outlined,
    AlertKind.desconhecido => Icons.notifications_none,
  };
}

AppStatus _alertStatus(AlertSeverity severity) {
  return switch (severity) {
    AlertSeverity.vencido => AppStatus.vencido,
    AlertSeverity.venceEmBreve => AppStatus.venceEmBreve,
    AlertSeverity.desconhecido => AppStatus.semPeriodicidade,
  };
}

// ---------------------------------------------------------------- pieces

class _OdometerCard extends StatelessWidget {
  const _OdometerCard({required this.odometer, this.plate, this.onTap});

  final DashboardOdometer odometer;
  final String? plate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final recordedOn = odometer.recordedOn;
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppMetric(
              value: formatKmNumber(odometer.currentKm),
              unit: 'km',
              label: recordedOn == null
                  ? 'Quilometragem atual'
                  : 'Quilometragem em ${formatCivilDate(recordedOn)}',
            ),
          ),
          if (plate != null && plate!.trim().isNotEmpty) ...[
            const SizedBox(width: AppSpacing.s8),
            _PlateChip(plate: plate!.trim()),
          ],
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.s8),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlateChip extends StatelessWidget {
  const _PlateChip({required this.plate});

  final String plate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.borderM,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        plate,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontFeatures: AppTypography.tabular,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, required this.phrase});

  final AppStatus status;
  final String phrase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = statusColors(status, theme.brightness);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: AppRadius.borderM,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sized against the line it sits beside, so the pair still reads as
          // one sentence at a 1.3 text scale.
          Icon(visual.icon, color: visual.foreground, size: 28),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              phrase,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: visual.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert, this.onTap});

  final Alert alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = _detailLine();

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _alertIcon(alert.kind),
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.s4),
                // Wrap rather than a Row: the chip label and the phrase are both
                // long in pt-BR, and at a 1.3 text scale on a 360dp phone they
                // have to be allowed to fall onto a second line.
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s4,
                  children: [
                    AppStatusChip(status: _alertStatus(alert.severity)),
                    if (detail != null)
                      Text(
                        detail,
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

  /// The server's own subtitle plus the remaining figures it computed. Never
  /// invents a subtitle, and never writes "0 km" for a dimension that came back
  /// null — null means the dimension does not apply.
  String? _detailLine() {
    final parts = <String>[];
    final subtitle = alert.subtitle?.trim();
    if (subtitle != null && subtitle.isNotEmpty) {
      parts.add(subtitle);
    }
    final due = dueSummary(
      remainingKm: alert.remainingKm,
      remainingDays: alert.remainingDays,
    );
    if (due != null) {
      parts.add(due);
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = statusColors(AppStatus.semBaseline, theme.brightness);
    final message = count == 1
        ? '1 item ainda não tem histórico. Informe a última vez que foi feito '
              'e o Meu Auto passa a avisar.'
        : '$count itens ainda não têm histórico. Informe a última vez que '
              'foram feitos e o Meu Auto passa a avisar.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: AppRadius.borderM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: visual.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(foregroundColor: visual.foreground),
              child: const Text('Configurar'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Deliberately quieter than the setup card: this is a nudge, not a deadline.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.message, this.onTap});

  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tune, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CostsCard extends StatelessWidget {
  const _CostsCard({required this.costs, this.onTap});

  final DashboardCosts costs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final includes = includedCategoriesLine(costs.trackedCategories);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            costPeriodLabel(costs.periodMonths),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            costs.trackedCents.format(),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontFeatures: AppTypography.tabular,
            ),
          ),
          if (includes != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(
              includes,
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

/// The skeleton mirrors the real layout — odometer block, status banner, a few
/// alert rows, cost block — because the shape of this screen is known before
/// the data arrives. A spinner would throw that information away.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: const [
        AppSkeleton(width: double.infinity, height: 96),
        SizedBox(height: AppSpacing.s16),
        AppSkeleton(width: double.infinity, height: 64),
        SizedBox(height: AppSpacing.s24),
        AppSkeletonList(),
        SizedBox(height: AppSpacing.s24),
        AppSkeleton(width: double.infinity, height: 88),
      ],
    );
  }
}
