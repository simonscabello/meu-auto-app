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
import 'package:meu_auto/features/abastecimento/presentation/abastecimento_form_sheet.dart';
import 'package:meu_auto/features/abastecimento/presentation/last_abastecimento_card.dart';
import 'package:meu_auto/features/dashboard/application/dashboard_provider.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_profile.dart';
import 'package:meu_auto/features/odometer/presentation/odometer_sheet.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

/// Início, for one vehicle. Owns the loading, error and content states and
/// hands the data to [DashboardContent], which knows nothing about providers.
class DashboardView extends ConsumerWidget {
  const DashboardView({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider(vehicleId));
    final vehicle = ref.watch(selectedVehicleProvider).value;

    return dashboard.when(
      loading: () => const _DashboardSkeleton(),
      error: (error, _) => AppErrorState.fromError(
        error: error,
        onRetry: () => ref.invalidate(dashboardProvider(vehicleId)),
      ),
      data: (data) => DashboardContent(
        dashboard: data,
        refuelingSupported: vehicle?.refueling.supported ?? false,
        onOdometerTap: () => OdometerSheet.show(
          context,
          vehicleId: vehicleId,
          currentMileageKm: data.odometer.currentKm,
        ),
        onProfileTap: () => context.push(AppRoutes.vehicleProfile),
        onSeeAllAlerts: () => context.go(AppRoutes.care),
        onAlertTap: (alert) => _openAlert(context, alert),
        onCostsTap: () => context.push(AppRoutes.costs),
        onAbastecimentoTap: () => context.push(AppRoutes.abastecimentos),
        onRegisterMaintenance: () => context.push(AppRoutes.maintenanceNew),
        onRegisterAbastecimento: vehicle == null
            ? null
            : () => AbastecimentoFormSheet.show(
                context,
                vehicleId: vehicle.id,
                currentMileageKm: vehicle.currentMileageKm,
                fuelTypes: vehicle.refueling.offeredFuels,
                lastFuel: data.lastAbastecimento?.fuel,
              ),
      ),
    );
  }

  /// `reference_type` says where an alert lives.
  void _openAlert(BuildContext context, Alert alert) {
    final route = routeForAlert(alert);
    if (route == AppRoutes.care) {
      context.go(route);
      return;
    }
    context.push(route);
  }
}

/// Where a dashboard alert should open. Unknown types land on Cuidados
/// rather than inventing a screen.
@visibleForTesting
String routeForAlert(Alert alert) {
  return switch (alert.referenceType) {
    AlertReferenceType.maintenanceRecord => AppRoutes.maintenanceRecord(
      alert.referenceId,
    ),
    AlertReferenceType.maintenancePlan => AppRoutes.plan(alert.referenceId),
    AlertReferenceType.obligation => AppRoutes.obligation(alert.referenceId),
    AlertReferenceType.seguro => AppRoutes.seguro(alert.referenceId),
    AlertReferenceType.desconhecido => AppRoutes.care,
  };
}

/// Início as pure presentation: the instrument panel of the car.
///
/// The screen is four blocks, in descending priority, and **every one of them
/// is a bounded group** — a label outside, its content inside one surface:
///
///  1. **The car.** Mileage as the hero figure with the plate beside it, and
///     the verdict directly under it. One panel, because "which car, how far,
///     is it fine" is one question asked three ways.
///  2. **What you came to do.** Two or three named actions, side by side.
///     Registering a fill or a service from Início is the most common reason
///     to open the app at all, and it used to take a tab change and an
///     app-bar icon to reach.
///  3. **What is coming**, and **what it has cost** — lists under quiet
///     labels.
///
/// It used to be the same content with no containers at all: a reading, a
/// band, some rows and a total, each floating directly on the page. That
/// solved a real problem — every fact had been inside its own outlined card —
/// but it left nothing saying where one group ended and the next began, and
/// the screen read as a pile of unrelated lines.
///
/// **The history prompt is deliberately not here.** "Falta informar" on a new
/// car covers a dozen items, none of them urgent, and putting it on the
/// screen the owner opens every day made the app nag about setup instead of
/// reporting on the car. It lives in Cuidados, under its own group, where
/// someone has already come to deal with upkeep.
///
/// Every number arrived computed by the server: `overdue`, `due_soon`,
/// `remaining_km`, `remaining_days`, `total_cents`. Nothing in this file
/// derives a due date, a status or a total; it turns figures into sentences.
class DashboardContent extends StatelessWidget {
  const DashboardContent({
    super.key,
    required this.dashboard,
    this.refuelingSupported = false,
    this.onOdometerTap,
    this.onProfileTap,
    this.onSeeAllAlerts,
    this.onAlertTap,
    this.onCostsTap,
    this.onAbastecimentoTap,
    this.onRegisterAbastecimento,
    this.onRegisterMaintenance,
  });

  final Dashboard dashboard;
  final bool refuelingSupported;
  final VoidCallback? onOdometerTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onSeeAllAlerts;
  final ValueChanged<Alert>? onAlertTap;
  final VoidCallback? onCostsTap;
  final VoidCallback? onAbastecimentoTap;
  final VoidCallback? onRegisterAbastecimento;
  final VoidCallback? onRegisterMaintenance;

  @override
  Widget build(BuildContext context) {
    final alerts = dashboard.alerts;
    final profilePrompt = profilePromptOf(dashboard.profile);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s16,
        AppSpacing.s32,
      ),
      children: [
        _VehiclePanel(
          odometer: dashboard.odometer,
          plate: dashboard.vehicle.plate,
          alerts: alerts,
          onOdometerTap: onOdometerTap,
          onStatusTap: onSeeAllAlerts,
        ),
        const SizedBox(height: appGroupGap),
        _QuickActions(
          onRegisterAbastecimento: refuelingSupported
              ? onRegisterAbastecimento
              : null,
          onRegisterMaintenance: onRegisterMaintenance,
          onOdometerTap: onOdometerTap,
        ),
        if (alerts.items.isNotEmpty) ...[
          const SizedBox(height: appGroupGap),
          AppGroup(
            title: 'Próximos cuidados',
            actionLabel: onSeeAllAlerts == null ? null : 'Ver todos',
            onAction: onSeeAllAlerts,
            children: [
              for (final alert in alerts.items)
                _AlertRow(
                  alert: alert,
                  onTap: onAlertTap == null ? null : () => onAlertTap!(alert),
                ),
            ],
          ),
        ],
        if (refuelingSupported) ...[
          const SizedBox(height: appGroupGap),
          LastAbastecimentoCard(
            supported: true,
            last: dashboard.lastAbastecimento,
            onTap: onAbastecimentoTap,
            onRegister: onRegisterAbastecimento,
          ),
        ],
        const SizedBox(height: appGroupGap),
        _CostsSection(costs: dashboard.costs, onTap: onCostsTap),
        if (profilePrompt != null) ...[
          const SizedBox(height: appGroupGap),
          AppGroup(
            children: [
              AppListRow(
                icon: Icons.tune,
                title: profilePrompt,
                onTap: onProfileTap,
                showChevron: onProfileTap != null,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- copy

/// The one sentence that answers whether the car is OK.
///
/// Priority order, and only one shows: something is late, something is close,
/// everything is fine.
///
/// `needs_baseline` is not in this list any more, on purpose. A car nobody has
/// filled the history for is not in a *state* — it is a car we have not been
/// told about yet, and reporting that where the verdict goes meant a brand
/// new vehicle spent its first weeks looking like it had a problem. Cuidados
/// asks for the history, in the group named after it.
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
  return 'Tudo em dia';
}

/// The status the verdict is painted in. Only two states are loud, and
/// [AppStatus.emDia] is the answer for everything else — including a car
/// whose history is still empty, which is a gap in what we know rather than
/// something wrong with the car.
@visibleForTesting
AppStatus statusOf(DashboardAlerts alerts) {
  if (alerts.overdue > 0) return AppStatus.vencido;
  if (alerts.dueSoon > 0) return AppStatus.venceEmBreve;
  return AppStatus.emDia;
}

/// The discreet line about what we still do not know about the car.
///
/// Null most of the time, and that is the design. It is down to the two gaps
/// that genuinely stop the app doing its job:
///
///  * no fuel type — nothing about the engine can be decided without it;
///  * no plan at all — there is nothing to report on.
///
/// The count of open profile questions used to be here too ("faltam 3
/// informações"). It moved to "O que o seu carro tem", which is where the
/// questions actually are: a number on Início that cannot be acted on from
/// Início is a nag, not a prompt.
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
  'obligations': 'IPVA e licenciamento',
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
    AlertKind.manutencao => Icons.build_outlined,
    AlertKind.cuidado => Icons.checklist_rtl,
    AlertKind.garantia => Icons.verified_user_outlined,
    AlertKind.ipva => Icons.receipt_long_outlined,
    AlertKind.licenciamento => Icons.description_outlined,
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

/// The car, as one panel: how far it has gone, which car it is, and whether
/// it is fine.
///
/// The reading and the verdict used to be two floating elements with a gap
/// between them. They are one object — the verdict is *about* this odometer
/// on this car — and drawing them as one panel split by a fill is what makes
/// that legible at a glance.
class _VehiclePanel extends StatelessWidget {
  const _VehiclePanel({
    required this.odometer,
    required this.alerts,
    this.plate,
    this.onOdometerTap,
    this.onStatusTap,
  });

  final DashboardOdometer odometer;
  final DashboardAlerts alerts;
  final String? plate;
  final VoidCallback? onOdometerTap;
  final VoidCallback? onStatusTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = statusOf(alerts);
    final visual = statusColors(status, theme.brightness);
    final loud =
        status == AppStatus.vencido || status == AppStatus.venceEmBreve;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: groupSurfaceColor(scheme),
        borderRadius: AppRadius.borderM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OdometerReading(
            odometer: odometer,
            plate: plate,
            onTap: onOdometerTap,
          ),
          // The verdict carries the status fill edge to edge along the foot
          // of the panel, so "something is late" registers before a word is
          // read — and looks like nothing at all when the car is fine.
          Material(
            color: loud ? visual.background : Colors.transparent,
            child: InkWell(
              onTap: onStatusTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSpacing.minTapTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        visual.icon,
                        size: 20,
                        color: loud ? visual.foreground : scheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Text(
                          statusPhraseOf(alerts),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: loud ? visual.foreground : scheme.onSurface,
                          ),
                        ),
                      ),
                      if (onStatusTap != null)
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: loud ? visual.foreground : scheme.outline,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The mileage, set as the reading on an instrument.
///
/// The size, the tabular figures and the space around it are what make it the
/// first thing on the screen — not a second container inside the panel it
/// already sits in.
class _OdometerReading extends StatelessWidget {
  const _OdometerReading({required this.odometer, this.plate, this.onTap});

  final DashboardOdometer odometer;
  final String? plate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recordedOn = odometer.recordedOn;
    final caption = recordedOn == null
        ? 'Quilometragem atual'
        : 'Atualizada em ${formatCivilDayMonth(recordedOn)}';

    final reading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FittedBox rather than a smaller type ramp: seven digits at a 1.6
        // text scale on a 360dp phone is wider than the column, and shrinking
        // the one number that matters beats wrapping it onto two lines.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              text: formatKmNumber(odometer.currentKm),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -1,
                fontFeatures: AppTypography.tabular,
              ),
              children: [
                TextSpan(
                  text: ' km',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Row(
          children: [
            Flexible(
              child: Text(
                caption,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (plate != null && plate!.trim().isNotEmpty) ...[
              const SizedBox(width: AppSpacing.s8),
              _PlateChip(plate: plate!.trim()),
            ],
          ],
        ),
      ],
    );

    final padded = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s12,
      ),
      child: Row(
        children: [
          Expanded(child: reading),
          if (onTap != null)
            Icon(Icons.edit_outlined, size: 20, color: scheme.outline),
        ],
      ),
    );

    if (onTap == null) {
      return padded;
    }

    return Semantics(
      button: true,
      label:
          '$caption. ${formatKm(odometer.currentKm)}. Atualizar quilometragem',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: padded),
      ),
    );
  }
}

/// The plate, drawn as a plate.
///
/// One of the two outlines left in the app, and it earns it: a Brazilian
/// plate is a physical object with a border, and the outline is what makes
/// seven characters read as one at a glance.
class _PlateChip extends StatelessWidget {
  const _PlateChip({required this.plate});

  final String plate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.borderXs,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        plate,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontFeatures: AppTypography.tabular,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// The two or three things someone opens the app to do, side by side.
///
/// Not the global "+" that used to sit in the navigation bar: that control
/// could not say what it would do, opened a menu of seven, and appeared on
/// screens where none of the seven made sense. These are named, they are on
/// the one screen where all of them are plausible, and each goes straight to
/// its own form.
///
/// Abastecer is absent — not disabled — on a vehicle that does not refuel.
class _QuickActions extends StatelessWidget {
  const _QuickActions({
    this.onRegisterAbastecimento,
    this.onRegisterMaintenance,
    this.onOdometerTap,
  });

  final VoidCallback? onRegisterAbastecimento;
  final VoidCallback? onRegisterMaintenance;
  final VoidCallback? onOdometerTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tiles = <Widget>[
      if (onRegisterAbastecimento != null)
        _QuickAction(
          icon: Icons.local_gas_station_outlined,
          label: 'Abastecer',
          onTap: onRegisterAbastecimento,
        ),
      _QuickAction(
        icon: Icons.build_outlined,
        label: 'Manutenção',
        onTap: onRegisterMaintenance,
      ),
      _QuickAction(
        icon: Icons.speed_outlined,
        label: 'Km atual',
        onTap: onOdometerTap,
      ),
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: groupSurfaceColor(scheme),
        borderRadius: AppRadius.borderM,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  indent: AppSpacing.s12,
                  endIndent: AppSpacing.s12,
                  color: scheme.outlineVariant.withValues(alpha: 0.45),
                ),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTapTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s8,
                vertical: AppSpacing.s12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 24, color: scheme.primary),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One upcoming item, as a row.
///
/// The status chip that used to sit here is gone: the group above says what
/// this list is, and [_detailLine] says how late or how close in words. The
/// tint on the icon is the third signal, never the only one.
class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert, this.onTap});

  final Alert alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _alertStatus(alert.severity);
    final visual = statusColors(status, theme.brightness);
    final overdue = alert.severity == AlertSeverity.vencido;
    final detail = _detailLine();

    return AppListRow(
      icon: _alertIcon(alert.kind),
      title: alert.title,
      subtitle: detail ?? visual.label,
      accent: overdue ? visual.foreground : null,
      onTap: onTap,
      showChevron: onTap != null,
      semanticLabel: detail == null
          ? '${alert.title}. ${visual.label}'
          : '${alert.title}. ${visual.label}. $detail',
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

/// What the car has cost, as a figure inside its own group.
///
/// The label carries the window and the footnote carries the caveat, so the
/// number itself can be set large and read in one go.
class _CostsSection extends StatelessWidget {
  const _CostsSection({required this.costs, this.onTap});

  final DashboardCosts costs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppGroup(
      title: costPeriodLabel(costs.periodMonths),
      footnote: includedCategoriesLine(costs.noteCategoryKeys),
      dividerIndent: 0,
      children: [
        AppListRowShell(
          onTap: onTap,
          semanticLabel:
              '${costPeriodLabel(costs.periodMonths)}. '
              '${costs.totalCents.format()}',
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    costs.totalCents.format(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, size: 20, color: scheme.outline),
            ],
          ),
        ),
      ],
    );
  }
}

/// The skeleton mirrors the real layout — a panel, a row of actions, a list,
/// a total — because the shape of this screen is known before the data
/// arrives. A spinner would throw that information away.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

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
        AppSkeleton(width: double.infinity, height: 132),
        SizedBox(height: appGroupGap),
        AppSkeleton(width: double.infinity, height: 76),
        SizedBox(height: appGroupGap),
        AppSkeleton(width: 140, height: 14),
        SizedBox(height: AppSpacing.s8),
        AppSkeleton(width: double.infinity, height: 148),
        SizedBox(height: appGroupGap),
        AppSkeleton(width: 200, height: 14),
        SizedBox(height: AppSpacing.s8),
        AppSkeleton(width: double.infinity, height: 64),
      ],
    );
  }
}
