import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/core/theme/app_tones.dart';
import 'package:meu_auto/features/abastecimento/presentation/abastecimento_form_sheet.dart';
import 'package:meu_auto/features/dashboard/application/dashboard_provider.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';
import 'package:meu_auto/features/dashboard/presentation/alert_row.dart';
import 'package:meu_auto/features/dashboard/presentation/mileage_display.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_profile.dart';
import 'package:meu_auto/features/maintenance/domain/plan_progress.dart';
import 'package:meu_auto/features/odometer/presentation/odometer_sheet.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_progress_bar.dart';
import 'package:meu_auto/shared/widgets/app_quick_action.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_surface.dart';

export 'package:meu_auto/features/dashboard/presentation/alert_row.dart'
    show routeForAlert;
export 'package:meu_auto/features/dashboard/presentation/mileage_display.dart'
    show odometerCaption, odometerIsStale;

/// Início, for one vehicle. Owns the loading, error and content states and
/// hands the data to [DashboardContent], which knows nothing about providers.
class DashboardView extends ConsumerWidget {
  const DashboardView({super.key, required this.vehicleId, this.header});

  final String vehicleId;

  /// The head of the page — the mark, the account and the car — which is
  /// known before the dashboard arrives and stays put while it loads.
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider(vehicleId));
    final vehicle = ref.watch(selectedVehicleProvider).valueOrNull;
    // The plans carry the interval an alert does not, which is what turns
    // "faltam 4.112 km" into a bar. The tab keeps them alive; reading them
    // here costs no request, and a list that has not arrived just means no
    // bars yet.
    final plans = ref.watch(maintenancePlansProvider(vehicleId)).valueOrNull;
    final progress = plans == null
        ? const <String, double>{}
        : planProgressById(plans);

    return dashboard.when(
      skipLoadingOnReload: true,
      loading: () => DashboardSkeleton(header: header),
      error: (error, _) => _WithHeader(
        header: header,
        child: AppErrorState.fromError(
          error: error,
          onRetry: () => ref.invalidate(dashboardProvider(vehicleId)),
        ),
      ),
      data: (data) => DashboardContent(
        dashboard: data,
        header: header,
        today: CivilDate.todayLocal(),
        refuelingSupported: vehicle?.refueling.supported ?? false,
        progressByReference: progress,
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

class _WithHeader extends StatelessWidget {
  const _WithHeader({required this.child, this.header});

  final Widget? header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (header == null) return child;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.s8,
            AppSpacing.page,
            0,
          ),
          child: header,
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Início as pure presentation. Five questions, in order, and nothing else:
///
///  1. **Which car?** The header.
///  2. **How far has it gone?** The mileage, as the hero figure, with the
///     pencil beside it — the one prominent way to update it.
///  3. **Does anything need me?** A discreet strip between two hairlines:
///     what is late or close, from every domain, red only on the glyph and
///     the figure. When nothing is, one quiet line says so — and says
///     honestly when the app does not know yet.
///  4. **What do I want to record?** Two named actions of exactly equal
///     weight.
///  5. **What comes next?** At most three upcoming items, each with how far
///     it is and — only when the figures allow it — how far along.
///
/// Costs and the last fill are not here. They live on Histórico, where the
/// question "what did this car cost" is the reason to open the tab.
///
/// Every number arrived computed by the server. Nothing in this file derives a
/// due date, a status or a total; it turns figures into sentences.
class DashboardContent extends StatelessWidget {
  const DashboardContent({
    super.key,
    required this.dashboard,
    this.header,
    this.today,
    this.refuelingSupported = false,
    this.progressByReference = const {},
    this.onOdometerTap,
    this.onProfileTap,
    this.onMaintenanceTap,
    this.onStartHistory,
    this.onSeeAllAlerts,
    this.onAlertTap,
    this.onRegisterAbastecimento,
    this.onRegisterMaintenance,
  });

  final Dashboard dashboard;
  final Widget? header;

  /// Only for how old the mileage reading is. Null leaves the caption as the
  /// date it was recorded.
  final CivilDate? today;

  final bool refuelingSupported;

  /// How far along each upcoming plan is, by plan id. An item with no entry
  /// gets no bar.
  final Map<String, double> progressByReference;

  final VoidCallback? onOdometerTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onMaintenanceTap;

  /// The history questions, for a car nobody has told the app about yet.
  final VoidCallback? onStartHistory;

  final VoidCallback? onSeeAllAlerts;
  final ValueChanged<Alert>? onAlertTap;
  final VoidCallback? onRegisterAbastecimento;
  final VoidCallback? onRegisterMaintenance;

  @override
  Widget build(BuildContext context) {
    final alerts = dashboard.alerts;
    final verdict = verdictOf(dashboard);
    final profilePrompt = profilePromptOf(dashboard.profile);
    final totalAlerts = alerts.overdue + alerts.dueSoon;
    final shown = alerts.items.take(_maxAlertsOnHome).toList();
    final seeAll = totalAlerts > shown.length ? onSeeAllAlerts : null;

    final quietRows = <Widget>[
      // The two gaps that stop the app working sit right under the verdict
      // they undermine: without a fuel type the engine items are simply
      // missing, and without a plan there is nothing to report on.
      if (profilePrompt != null)
        AppListRow(
          icon: Icons.tune_outlined,
          title: profilePrompt,
          onTap: onProfileTap,
          showChevron: onProfileTap != null,
        ),
      // The next step for a car the app knows nothing about. Not a nag: it
      // shows only while there are questions nobody was asked, and goes away
      // the moment they are answered — "não sei" included.
      if (verdict.kind == VerdictKind.unknown &&
          alerts.needsBaseline > 0 &&
          onStartHistory != null)
        AppListRow(
          icon: Icons.fact_check_outlined,
          title: 'Conte o que já foi feito no carro',
          subtitle: 'Algumas perguntas rápidas. Depois, o aviso chega na hora',
          onTap: onStartHistory,
          showChevron: true,
        ),
      // With something late or close the verdict speaks about that, and the
      // items nobody knows about would go unmentioned. One quiet row keeps
      // them on the screen without competing with what is overdue.
      if (verdict.kind != VerdictKind.unknown && alerts.itemsWithoutHistory > 0)
        AppListRow(
          icon: Icons.help_outline,
          title: unknownHistoryPhrase(alerts.itemsWithoutHistory),
          subtitle: 'Informe quando foram feitos para receber o aviso',
          onTap: onMaintenanceTap,
          showChevron: onMaintenanceTap != null,
        ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s8,
        AppSpacing.page,
        AppSpacing.s40,
      ),
      children: [
        if (header != null) ...[
          header!,
          const SizedBox(height: AppSpacing.block),
        ],
        MileageDisplay(
          currentKm: dashboard.odometer.currentKm,
          caption: odometerCaption(dashboard.odometer.recordedOn, today),
          stale: odometerIsStale(dashboard.odometer.recordedOn, today),
          onTap: onOdometerTap,
        ),
        const SizedBox(height: AppSpacing.block),
        AttentionStrip(
          verdict: verdict,
          alerts: shown,
          seeAllLabel: seeAll == null ? null : 'Ver todos ($totalAlerts)',
          onSeeAll: seeAll,
          onHeaderTap: _verdictTap(verdict, seeAll),
          onAlertTap: onAlertTap,
          quietRows: quietRows,
        ),
        const SizedBox(height: AppSpacing.block),
        _QuickActions(
          onRegisterAbastecimento: refuelingSupported
              ? onRegisterAbastecimento
              : null,
          onRegisterMaintenance: onRegisterMaintenance,
        ),
        if (dashboard.upcoming.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s32),
          AppSectionHeader(
            title: 'Próximos cuidados',
            emphasis: AppSectionEmphasis.title,
            actionLabel: onMaintenanceTap == null ? null : 'Ver todos',
            onAction: onMaintenanceTap,
          ),
          for (var i = 0; i < dashboard.upcoming.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.s12),
            UpcomingCareCard(
              alert: dashboard.upcoming[i],
              progress: progressByReference[dashboard.upcoming[i].referenceId],
              onTap: onAlertTap == null
                  ? null
                  : () => onAlertTap!(dashboard.upcoming[i]),
            ),
          ],
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

/// How many late or close items Início lists before pointing at the full
/// list. Three is what fits above the fold on a small phone with the mileage
/// still visible.
const _maxAlertsOnHome = 3;

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
/// The phrase names what it counts. Late says "vencidos", and what is close
/// besides goes on the quiet second line.
///
/// "Unknown" is neutral on purpose: a car nobody has told the app about is
/// not "em dia", and it is not broken either. "Nada vencido até agora" is
/// true, and the line under it says what is missing, in grey rather than in
/// the status colours.
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
        'É o que define o que ele precisa — e o que não precisa.';
  }
  if (profile.status == MaintenanceProfileStatus.unknown) {
    return 'Ainda não temos um plano para este carro. '
        'Você escolhe o que quer acompanhar.';
  }
  return null;
}

// ---------------------------------------------------------------- pieces

/// What needs attention, as a strip between two hairlines.
///
/// No card: the strip is part of the page. The head of it is the verdict —
/// the glyph in a tinted well, the count, the quiet detail — and under it the
/// items themselves, three at most. Red appears on the glyph and on the
/// figure that says how late, and nowhere else. When nothing is late the
/// strip is one line, and it stays honest: "we do not know yet" is one of
/// its states.
class AttentionStrip extends StatelessWidget {
  const AttentionStrip({
    super.key,
    required this.verdict,
    this.alerts = const [],
    this.seeAllLabel,
    this.onSeeAll,
    this.onHeaderTap,
    this.onAlertTap,
    this.quietRows = const [],
  });

  final DashboardVerdict verdict;
  final List<Alert> alerts;
  final String? seeAllLabel;
  final VoidCallback? onSeeAll;
  final VoidCallback? onHeaderTap;
  final ValueChanged<Alert>? onAlertTap;

  /// Rows about what is missing rather than what is late, in the same strip
  /// so the page does not grow a second list.
  final List<Widget> quietRows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);
    final visual = statusColors(verdict.status, theme.brightness);
    final loud = verdict.loud;

    final (tone, icon) = switch (verdict.kind) {
      VerdictKind.overdue ||
      VerdictKind.dueSoon => (AppIconWellTone.status, visual.icon),
      VerdictKind.fine => (AppIconWellTone.accent, Icons.check_circle_outline),
      VerdictKind.unknown || VerdictKind.nothingTracked => (
        AppIconWellTone.neutral,
        Icons.help_outline,
      ),
    };

    final head = AppListRow(
      icon: icon,
      iconTone: tone,
      status: verdict.status,
      title: verdict.phrase,
      subtitle: verdict.detail,
      accent: loud ? null : scheme.onSurfaceVariant,
      onTap: onHeaderTap,
      showChevron: onHeaderTap != null && onSeeAll == null,
      trailing: onSeeAll == null
          ? null
          : AppSectionAction(
              label: seeAllLabel ?? 'Ver todos',
              onPressed: onSeeAll,
            ),
      semanticLabel: verdict.detail == null
          ? verdict.phrase
          : '${verdict.phrase}. ${verdict.detail}',
    );

    final rows = <Widget>[
      head,
      for (final alert in alerts)
        AlertRow(
          alert: alert,
          onTap: onAlertTap == null ? null : () => onAlertTap!(alert),
        ),
      ...quietRows,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, thickness: 1, color: tones.divider),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            Divider(height: 1, thickness: 1, indent: 50, color: tones.divider),
          rows[i],
        ],
        Divider(height: 1, thickness: 1, color: tones.divider),
      ],
    );
  }
}

/// The two things someone opens the app to do, side by side and identical.
///
/// Abastecer is absent — not disabled — on a vehicle that does not refuel,
/// and Registrar manutenção then takes the whole width.
class _QuickActions extends StatelessWidget {
  const _QuickActions({
    this.onRegisterAbastecimento,
    this.onRegisterMaintenance,
  });

  final VoidCallback? onRegisterAbastecimento;
  final VoidCallback? onRegisterMaintenance;

  @override
  Widget build(BuildContext context) {
    final maintenance = AppQuickAction(
      icon: Icons.build_outlined,
      label: 'Registrar manutenção',
      onTap: onRegisterMaintenance,
      wide: onRegisterAbastecimento == null,
    );
    if (onRegisterAbastecimento == null) {
      return maintenance;
    }
    // IntrinsicHeight so the two tiles are the same height whatever their
    // labels wrap to; two children, so the second layout pass is nothing.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AppQuickAction(
              icon: Icons.local_gas_station_outlined,
              label: 'Abastecer',
              onTap: onRegisterAbastecimento,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(child: maintenance),
        ],
      ),
    );
  }
}

/// One upcoming item: what it is, how far it is, and — when the figures
/// allow it — how far along.
class UpcomingCareCard extends StatelessWidget {
  const UpcomingCareCard({
    super.key,
    required this.alert,
    this.progress,
    this.onTap,
  });

  final Alert alert;

  /// 0 to 1, or null for no bar. Never estimated here.
  final double? progress;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final detail = alertDetailLine(alert);

    return Semantics(
      button: onTap != null,
      label: detail == null ? alert.title : '${alert.title}. $detail',
      excludeSemantics: true,
      child: AppSurface(
        variant: AppSurfaceVariant.grouped,
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                AppIconWell(
                  icon: alertIconOf(alert.kind),
                  size: AppIconWellSize.l,
                ),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        alert.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (detail != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: AppSpacing.s8),
                  Icon(Icons.chevron_right, size: 20, color: scheme.outline),
                ],
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: AppSpacing.s16),
              AppProgressBar(value: progress!),
            ],
          ],
        ),
      ),
    );
  }
}

/// The skeleton mirrors the real layout — the reading, a strip, two tiles, a
/// list — because the shape of this screen is known before the data arrives.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key, this.header});

  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.s8,
        AppSpacing.page,
        AppSpacing.s40,
      ),
      children: [
        if (header != null) ...[
          header!,
          const SizedBox(height: AppSpacing.block),
        ] else ...[
          const AppSkeleton(width: 96, height: 18),
          const SizedBox(height: AppSpacing.s20),
          const AppSkeleton(width: 180, height: 36),
          const SizedBox(height: AppSpacing.s8),
          const AppSkeleton(width: 220, height: 16),
          const SizedBox(height: AppSpacing.block),
        ],
        const AppSkeleton(width: 150, height: 14),
        const SizedBox(height: AppSpacing.s12),
        const AppSkeleton(width: 240, height: 56),
        const SizedBox(height: AppSpacing.s12),
        const AppSkeleton(width: 190, height: 14),
        const SizedBox(height: AppSpacing.block),
        const AppSkeleton(width: double.infinity, height: 64),
        const SizedBox(height: AppSpacing.block),
        const Row(
          children: [
            Expanded(child: AppSkeleton(height: 112)),
            SizedBox(width: AppSpacing.s12),
            Expanded(child: AppSkeleton(height: 112)),
          ],
        ),
        const SizedBox(height: AppSpacing.s32),
        const AppSkeleton(width: 170, height: 18),
        const SizedBox(height: AppSpacing.s12),
        const AppSkeleton(width: double.infinity, height: 92),
        const SizedBox(height: AppSpacing.s12),
        const AppSkeleton(width: double.infinity, height: 92),
      ],
    );
  }
}
