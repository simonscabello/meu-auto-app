import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/core/theme/app_typography.dart';
import 'package:meu_auto/features/abastecimento/presentation/abastecimento_form_sheet.dart';
import 'package:meu_auto/features/abastecimento/presentation/last_abastecimento_card.dart';
import 'package:meu_auto/features/dashboard/application/dashboard_provider.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';
import 'package:meu_auto/features/dashboard/presentation/alert_row.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_profile.dart';
import 'package:meu_auto/features/odometer/presentation/odometer_sheet.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

export 'package:meu_auto/features/dashboard/presentation/alert_row.dart'
    show routeForAlert;

/// Início, for one vehicle. Owns the loading, error and content states and
/// hands the data to [DashboardContent], which knows nothing about providers.
class DashboardView extends ConsumerWidget {
  const DashboardView({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider(vehicleId));
    final vehicle = ref.watch(selectedVehicleProvider).valueOrNull;

    return dashboard.when(
      skipLoadingOnReload: true,
      loading: () => const _DashboardSkeleton(),
      error: (error, _) => AppErrorState.fromError(
        error: error,
        onRetry: () => ref.invalidate(dashboardProvider(vehicleId)),
      ),
      data: (data) => DashboardContent(
        dashboard: data,
        today: CivilDate.todayLocal(),
        refuelingSupported: vehicle?.refueling.supported ?? false,
        onOdometerTap: () => OdometerSheet.show(
          context,
          vehicleId: vehicleId,
          currentMileageKm: data.odometer.currentKm,
        ),
        onProfileTap: () => context.push(AppRoutes.vehicleProfile),
        onMaintenanceTap: () => context.go(AppRoutes.care),
        onStartHistory: () => context.push(AppRoutes.calibrar(vehicleId)),
        onSeeAllAlerts: () => context.push(AppRoutes.alerts),
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

  void _openAlert(BuildContext context, Alert alert) {
    final route = routeForAlert(alert);
    if (route == AppRoutes.care) {
      context.go(route);
      return;
    }
    context.push(route);
  }
}

/// Início as pure presentation: how the car is, what to do now, what comes
/// next.
///
/// In order, and every block a bounded group:
///
///  1. **The car.** Mileage as the hero figure, and the verdict under it. The
///     verdict has four states, not three: something is late, something is
///     close, *we do not know yet*, and everything is fine. The third one is
///     the fix for a brand-new car greeted with a green "Tudo em dia" while
///     the app knew nothing about it — including right after the owner said
///     "não sei" to every history question.
///  2. **What you came to do.** Named actions, side by side.
///  3. **Precisa de atenção** — what is late or close, from every domain.
///  4. **Em seguida** — what comes next among the things that are fine. Before
///     it, a car with nothing due showed a verdict and nothing else, and
///     "what is coming?" is the owner's most valuable question.
///  5. The last fill and what the car has cost, when there is one.
///
/// Every number arrived computed by the server. Nothing in this file derives a
/// due date, a status or a total; it turns figures into sentences.
class DashboardContent extends StatelessWidget {
  const DashboardContent({
    super.key,
    required this.dashboard,
    this.today,
    this.refuelingSupported = false,
    this.onOdometerTap,
    this.onProfileTap,
    this.onMaintenanceTap,
    this.onStartHistory,
    this.onSeeAllAlerts,
    this.onAlertTap,
    this.onCostsTap,
    this.onAbastecimentoTap,
    this.onRegisterAbastecimento,
    this.onRegisterMaintenance,
  });

  final Dashboard dashboard;

  /// Only for how old the mileage reading is. Null leaves the caption as the
  /// date it was recorded.
  final CivilDate? today;

  final bool refuelingSupported;
  final VoidCallback? onOdometerTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onMaintenanceTap;

  /// The history questions, for a car nobody has told the app about yet.
  final VoidCallback? onStartHistory;

  final VoidCallback? onSeeAllAlerts;
  final ValueChanged<Alert>? onAlertTap;
  final VoidCallback? onCostsTap;
  final VoidCallback? onAbastecimentoTap;
  final VoidCallback? onRegisterAbastecimento;
  final VoidCallback? onRegisterMaintenance;

  @override
  Widget build(BuildContext context) {
    final alerts = dashboard.alerts;
    final verdict = verdictOf(dashboard);
    final profilePrompt = profilePromptOf(dashboard.profile);
    final totalAlerts = alerts.overdue + alerts.dueSoon;
    final showCosts = dashboard.costs.totalCents.cents > 0;
    final seeAll = totalAlerts > alerts.items.length ? onSeeAllAlerts : null;

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
          verdict: verdict,
          today: today,
          onOdometerTap: onOdometerTap,
          onVerdictTap: _verdictTap(verdict, seeAll),
        ),
        // The two gaps that stop the app working sit right under the verdict
        // they undermine: without a fuel type the engine items are simply
        // missing, and without a plan there is nothing to report on.
        if (profilePrompt != null) ...[
          const SizedBox(height: AppSpacing.s12),
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
        // The next step for a car the app knows nothing about. Not a nag: it
        // shows only while there are questions nobody was asked, and goes away
        // the moment they are answered — "não sei" included.
        if (verdict.kind == VerdictKind.unknown &&
            alerts.needsBaseline > 0 &&
            onStartHistory != null) ...[
          const SizedBox(height: AppSpacing.s12),
          AppGroup(
            children: [
              AppListRow(
                icon: Icons.fact_check_outlined,
                title: 'Conte o que já foi feito no carro',
                subtitle:
                    'Algumas perguntas rápidas, e o Meu Auto passa a avisar '
                    'na hora certa',
                onTap: onStartHistory,
                showChevron: true,
              ),
            ],
          ),
        ],
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
            title: 'Precisa de atenção',
            actionLabel: seeAll == null ? null : 'Ver todos ($totalAlerts)',
            onAction: seeAll,
            children: [
              for (final alert in alerts.items)
                AlertRow(
                  alert: alert,
                  onTap: onAlertTap == null ? null : () => onAlertTap!(alert),
                ),
            ],
          ),
        ],
        if (dashboard.upcoming.isNotEmpty) ...[
          const SizedBox(height: appGroupGap),
          AppGroup(
            title: 'Em seguida',
            children: [
              for (final item in dashboard.upcoming)
                AlertRow(
                  alert: item,
                  onTap: onAlertTap == null ? null : () => onAlertTap!(item),
                ),
            ],
          ),
        ],
        // With something late or close the verdict speaks about that, and the
        // items nobody knows about would go unmentioned. One quiet row keeps
        // them on the screen without competing with what is overdue.
        if (verdict.kind != VerdictKind.unknown &&
            alerts.itemsWithoutHistory > 0) ...[
          const SizedBox(height: appGroupGap),
          AppGroup(
            children: [
              AppListRow(
                icon: Icons.help_outline,
                title: unknownHistoryPhrase(alerts.itemsWithoutHistory),
                subtitle:
                    'Informe quando foram feitos e o Meu Auto passa a avisar',
                onTap: onMaintenanceTap,
                showChevron: onMaintenanceTap != null,
              ),
            ],
          ),
        ],
        if (refuelingSupported && dashboard.lastAbastecimento != null) ...[
          const SizedBox(height: appGroupGap),
          LastAbastecimentoCard(
            supported: true,
            last: dashboard.lastAbastecimento,
            onTap: onAbastecimentoTap,
            onRegister: onRegisterAbastecimento,
          ),
        ],
        if (showCosts) ...[
          const SizedBox(height: appGroupGap),
          _CostsSection(costs: dashboard.costs, onTap: onCostsTap),
        ],
      ],
    );
  }

  /// Late or close: the full list when Início could not show all of it,
  /// otherwise the maintenance tab. Unknown or fine: the maintenance tab,
  /// where the items live. Nothing tracked: the screen that adds a plan.
  VoidCallback? _verdictTap(DashboardVerdict verdict, VoidCallback? seeAll) {
    return switch (verdict.kind) {
      VerdictKind.overdue || VerdictKind.dueSoon => seeAll ?? onMaintenanceTap,
      VerdictKind.unknown || VerdictKind.fine => onMaintenanceTap,
      VerdictKind.nothingTracked => onProfileTap,
    };
  }
}

// ---------------------------------------------------------------- verdict

enum VerdictKind { overdue, dueSoon, unknown, nothingTracked, fine }

/// The one sentence that answers whether the car is OK, and the state it is
/// painted in.
@immutable
final class DashboardVerdict {
  const DashboardVerdict({
    required this.kind,
    required this.phrase,
    this.detail,
  });

  final VerdictKind kind;
  final String phrase;

  /// A second, quieter line — what is close when something is already late,
  /// or how many items are unknown.
  final String? detail;

  AppStatus get status => switch (kind) {
    VerdictKind.overdue => AppStatus.vencido,
    VerdictKind.dueSoon => AppStatus.venceEmBreve,
    VerdictKind.fine => AppStatus.emDia,
    VerdictKind.unknown || VerdictKind.nothingTracked => AppStatus.semBaseline,
  };

  bool get loud => kind == VerdictKind.overdue || kind == VerdictKind.dueSoon;
}

/// Priority order, and only one shows: late, close, unknown, fine.
///
/// The phrase names what it counts. It used to say "2 itens precisam de
/// atenção" while counting only the late ones, right above a group with that
/// very title listing three — the one due soon included. Late says "vencidos",
/// and what is close besides goes on the quiet second line.
///
/// "Unknown" is neutral on purpose. It used to be folded into "Tudo em dia",
/// because putting a dozen setup prompts where the verdict goes made a new car
/// look broken — and the fix went one step too far the other way, into
/// claiming a car was fine when nothing was known about it. "Nada vencido até
/// agora" is true, and the line under it says what is missing, in grey rather
/// than in the status colours.
@visibleForTesting
DashboardVerdict verdictOf(Dashboard dashboard) {
  final alerts = dashboard.alerts;
  if (alerts.overdue > 0) {
    return DashboardVerdict(
      kind: VerdictKind.overdue,
      phrase: alerts.overdue == 1
          ? '1 item vencido'
          : '${alerts.overdue} itens vencidos',
      detail: switch (alerts.dueSoon) {
        0 => null,
        1 => 'Mais 1 vence em breve',
        final n => 'Mais $n vencem em breve',
      },
    );
  }
  if (alerts.dueSoon > 0) {
    return DashboardVerdict(
      kind: VerdictKind.dueSoon,
      phrase: alerts.dueSoon == 1
          ? '1 item vence em breve'
          : '${alerts.dueSoon} itens vencem em breve',
    );
  }
  if (dashboard.profile.status == MaintenanceProfileStatus.unknown) {
    return const DashboardVerdict(
      kind: VerdictKind.nothingTracked,
      phrase: 'Nenhum item acompanhado ainda',
    );
  }
  final unknown = alerts.itemsWithoutHistory;
  if (unknown > 0) {
    return DashboardVerdict(
      kind: VerdictKind.unknown,
      phrase: 'Nada vencido até agora',
      detail: unknownHistoryPhrase(unknown),
    );
  }
  return const DashboardVerdict(kind: VerdictKind.fine, phrase: 'Tudo em dia');
}

/// "12 itens sem data da última vez" — the items whose next due date nobody
/// can compute yet.
@visibleForTesting
String unknownHistoryPhrase(int count) {
  if (count == 1) return '1 item sem data da última vez';
  return '$count itens sem data da última vez';
}

/// The discreet line about what we still do not know about the car.
///
/// Null most of the time, and that is the design. It is down to the two gaps
/// that genuinely stop the app doing its job:
///
///  * no fuel type — nothing about the engine can be decided without it;
///  * no plan at all — there is nothing to report on.
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

/// How old the mileage is, when that matters.
///
/// Every distance-based due date is measured from this number, and the server
/// has no way to know the car kept moving. A reading months old makes "faltam
/// 3.000 km" a guess, so past about six weeks the caption says how old it is
/// and asks for a new one — the whole panel is already the way to update it.
@visibleForTesting
String odometerCaption(CivilDate? recordedOn, CivilDate? today) {
  if (recordedOn == null) return 'Quilometragem atual';
  if (today == null) return 'Atualizada em ${formatCivilDayMonth(recordedOn)}';
  final days = recordedOn.daysUntil(today);
  if (days <= 0) return 'Atualizada hoje';
  if (days == 1) return 'Atualizada ontem';
  if (days <= _staleAfterDays) {
    return 'Atualizada em ${formatCivilDayMonth(recordedOn)}';
  }
  final months = (days / 30).round();
  final age = months <= 1 ? 'há mais de um mês' : 'há $months meses';
  return 'Atualizada $age — toque para conferir';
}

/// Whether [odometerCaption] is asking for a new reading.
@visibleForTesting
bool odometerIsStale(CivilDate? recordedOn, CivilDate? today) {
  if (recordedOn == null || today == null) return false;
  return recordedOn.daysUntil(today) > _staleAfterDays;
}

const _staleAfterDays = 45;

/// `cost_months` is a rolling window measured back from `since`, not a calendar
/// month. Calling one month "este mês" would be wrong on every day but the 1st.
@visibleForTesting
String costPeriodLabel(int periodMonths) {
  if (periodMonths == 1) {
    return 'Gastos registrados · últimos 30 dias';
  }
  return 'Gastos registrados · últimos $periodMonths meses';
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
/// Required by the contract, and by honesty: without day-to-day expenses this
/// figure is a partial sum, and presenting it as the cost of running the car
/// would be a lie. An unmapped category is shown raw rather than dropped, so a
/// category added later still appears.
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

// ---------------------------------------------------------------- pieces

/// The car, as one panel: how far it has gone, which car it is, and whether
/// it is fine.
class _VehiclePanel extends StatelessWidget {
  const _VehiclePanel({
    required this.odometer,
    required this.verdict,
    this.plate,
    this.today,
    this.onOdometerTap,
    this.onVerdictTap,
  });

  final DashboardOdometer odometer;
  final DashboardVerdict verdict;
  final String? plate;
  final CivilDate? today;
  final VoidCallback? onOdometerTap;
  final VoidCallback? onVerdictTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visual = statusColors(verdict.status, theme.brightness);
    final loud = verdict.loud;
    final fine = verdict.kind == VerdictKind.fine;

    final iconColor = loud
        ? visual.foreground
        : fine
        ? scheme.primary
        : scheme.onSurfaceVariant;
    final icon = switch (verdict.kind) {
      VerdictKind.unknown || VerdictKind.nothingTracked => Icons.help_outline,
      _ => visual.icon,
    };

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
            today: today,
            onTap: onOdometerTap,
          ),
          // The verdict carries the status fill edge to edge along the foot
          // of the panel, so "something is late" registers before a word is
          // read — and looks like nothing at all when the car is fine.
          Semantics(
            button: onVerdictTap != null,
            label: verdict.detail == null
                ? verdict.phrase
                : '${verdict.phrase}. ${verdict.detail}',
            excludeSemantics: true,
            child: Material(
              color: loud ? visual.background : Colors.transparent,
              child: InkWell(
                onTap: onVerdictTap,
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
                        Icon(icon, size: 20, color: iconColor),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                verdict.phrase,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: loud
                                      ? visual.foreground
                                      : scheme.onSurface,
                                ),
                              ),
                              if (verdict.detail != null)
                                Text(
                                  verdict.detail!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (onVerdictTap != null)
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
          ),
        ],
      ),
    );
  }
}

/// The mileage, set as the reading on an instrument.
class _OdometerReading extends StatelessWidget {
  const _OdometerReading({
    required this.odometer,
    this.plate,
    this.today,
    this.onTap,
  });

  final DashboardOdometer odometer;
  final String? plate;
  final CivilDate? today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final caption = odometerCaption(odometer.recordedOn, today);
    final stale = odometerIsStale(odometer.recordedOn, today);

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
            if (stale) ...[
              Icon(Icons.update, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.s4),
            ],
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
/// Named, on the one screen where all of them are plausible, each going
/// straight to its own form. Abastecer is absent — not disabled — on a
/// vehicle that does not refuel.
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
        label: 'Atualizar km',
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

/// What the car has cost, as a figure inside its own group.
///
/// Only when there is something to report: a new car's "R$ 0,00" under a
/// "custo registrado" label read like a finding rather than an empty page.
/// The full breakdown is one tap away here and always one tab away in
/// Histórico.
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

/// The skeleton mirrors the real layout — a panel, a row of actions, a list —
/// because the shape of this screen is known before the data arrives.
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
      ],
    );
  }
}
