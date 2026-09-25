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
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_profile.dart';
import 'package:meu_auto/features/maintenance/domain/plan_progress.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_icons.dart';
import 'package:meu_auto/features/odometer/presentation/odometer_sheet.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_quick_action.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

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
    // The same list gives each maintenance alert its item's own glyph: an
    // alert carries the plan's id but not its catalogue slug.
    final icons = <String, IconData>{
      for (final plan in plans ?? const <MaintenancePlan>[])
        plan.id: maintenanceIconFor(plan.itemSlug),
    };

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
        iconByReference: icons,
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

/// Início as pure presentation. Five questions, in this order, and nothing
/// else:
///
///  1. **Which car?** The header — the name, make and year, the plate.
///  2. **How far has it gone?** The mileage, the largest figure on the
///     screen, with "Atualizar" on the same line.
///  3. **Does anything need me?** The items themselves — "Calibrar os pneus ·
///     Venceu há 13 dias" — at most two, red or amber only on the glyph and
///     the line that says how late. With nothing late, one quiet line says so,
///     and says honestly when the app does not know yet.
///  4. **What can I record now?** Two named actions of exactly equal weight.
///  5. **What comes next?** The next two things among what is on track, and
///     the way to all of them.
///
/// A block that has nothing to say does not exist, but no block ever changes
/// place with another: Início is read at a glance, and a screen whose parts
/// move has to be read in full every time.
///
/// Costs, consumption and the last fill are not here. They are true and
/// useful, and they answer "what did this car cost?", which is Histórico's
/// question — here they would be metrics for the sake of having data.
///
/// Every number arrived computed by the server. Nothing in this file derives
/// a due date, a status or a total; it turns figures into sentences.
class DashboardContent extends StatelessWidget {
  const DashboardContent({
    super.key,
    required this.dashboard,
    this.header,
    this.today,
    this.refuelingSupported = false,
    this.progressByReference = const {},
    this.iconByReference = const {},
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

  /// How far along each upcoming plan is, by plan id. Kept for the callers
  /// that already compute it; Início no longer draws the bars — a gauge on
  /// every row was a metric added because the data existed.
  final Map<String, double> progressByReference;

  /// A glyph per referenced plan id, for the rows that point at a plan.
  final Map<String, IconData> iconByReference;

  final VoidCallback? onOdometerTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onMaintenanceTap;

  /// The history questions, for a car nobody has told the app about yet.
  final VoidCallback? onStartHistory;

  final VoidCallback? onSeeAllAlerts;
  final ValueChanged<Alert>? onAlertTap;
  final VoidCallback? onRegisterAbastecimento;
  final VoidCallback? onRegisterMaintenance;

  /// How many late or close items Início shows before "Ver todos".
  static const attentionLimit = 2;

  /// How many upcoming items Início shows.
  static const upcomingLimit = 2;

  @override
  Widget build(BuildContext context) {
    final verdict = verdictOf(dashboard);
    final upcoming = dashboard.upcoming.take(upcomingLimit).toList();

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
          const SizedBox(height: AppSpacing.s24),
        ],
        MileageDisplay(
          currentKm: dashboard.odometer.currentKm,
          caption: odometerCaption(dashboard.odometer.recordedOn, today),
          stale: odometerIsStale(dashboard.odometer.recordedOn, today),
          onTap: onOdometerTap,
        ),
        const SizedBox(height: AppSpacing.block),
        HomeAttention(
          verdict: verdict,
          alerts: dashboard.alerts,
          profilePrompt: profilePromptOf(dashboard.profile),
          onAlertTap: onAlertTap,
          iconByReference: iconByReference,
          onSeeAll: onSeeAllAlerts ?? onMaintenanceTap,
          onUnknownTap: dashboard.alerts.needsBaseline > 0
              ? (onStartHistory ?? onMaintenanceTap)
              : onMaintenanceTap,
          onProfileTap: onProfileTap,
        ),
        const SizedBox(height: AppSpacing.block),
        _QuickActions(
          onRegisterAbastecimento: refuelingSupported
              ? onRegisterAbastecimento
              : null,
          onRegisterMaintenance: onRegisterMaintenance,
        ),
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s32),
          AppGroup(
            title: upcoming.length == 1
                ? 'Próximo cuidado'
                : 'Próximos cuidados',
            children: [
              for (final alert in upcoming)
                AppListRow(
                  icon:
                      iconByReference[alert.referenceId] ??
                      alertIconOf(alert.kind),
                  title: alert.title,
                  subtitle: alertDetailLine(alert),
                  onTap: onAlertTap == null ? null : () => onAlertTap!(alert),
                  showChevron: onAlertTap != null,
                ),
              if (onMaintenanceTap != null)
                AppListRow(
                  title: 'Ver todas as manutenções',
                  iconTone: AppIconWellTone.accent,
                  onTap: onMaintenanceTap,
                  showChevron: true,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// "Does anything need me?", answered with the items themselves.
///
/// **The item, not a count of items.** "1 item vencido" made the owner tap to
/// learn *what* — and then read "Calibrar os pneus" again on the next page.
/// The row now says what and how late in one line, and opens the item.
/// Beyond [DashboardContent.attentionLimit] the rest are behind "Ver todos".
///
/// **No red box.** Red is on the glyph and on "Venceu há 13 dias", and
/// nowhere else: the card is the same card as every other on the screen, so
/// one late item does not turn the whole of Início into an error state.
///
/// With nothing late or close there is no list to show, and the block
/// becomes one line — "Tudo em dia", or the honest "Nada vencido até agora"
/// when the app does not know the history of some items yet.
class HomeAttention extends StatelessWidget {
  const HomeAttention({
    super.key,
    required this.verdict,
    required this.alerts,
    this.profilePrompt,
    this.onAlertTap,
    this.iconByReference = const {},
    this.onSeeAll,
    this.onUnknownTap,
    this.onProfileTap,
  });

  final DashboardVerdict verdict;
  final DashboardAlerts alerts;

  /// One of the two gaps that stop the app working — no fuel, no plan.
  final String? profilePrompt;

  final ValueChanged<Alert>? onAlertTap;
  final Map<String, IconData> iconByReference;
  final VoidCallback? onSeeAll;
  final VoidCallback? onUnknownTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final loudItems = [
      for (final alert in alerts.items)
        if (alert.severity == AlertSeverity.vencido ||
            alert.severity == AlertSeverity.venceEmBreve)
          alert,
    ];
    final shown = loudItems.take(DashboardContent.attentionLimit).toList();
    final total = alerts.overdue + alerts.dueSoon;
    final hidden =
        (total > loudItems.length ? total : loudItems.length) - shown.length;
    final unknown = alerts.itemsWithoutHistory;

    final prompt = profilePrompt == null
        ? null
        : AppListRow(
            icon: Icons.tune_outlined,
            title: profilePrompt!,
            onTap: onProfileTap,
            showChevron: onProfileTap != null,
          );

    if (shown.isNotEmpty) {
      return AppGroup(
        title: 'Precisa de atenção',
        children: [
          for (final alert in shown)
            AlertRow(
              alert: alert,
              icon: iconByReference[alert.referenceId],
              onTap: onAlertTap == null ? null : () => onAlertTap!(alert),
            ),
          if (hidden > 0 && onSeeAll != null)
            AppListRow(
              title: hidden == 1
                  ? 'Ver mais 1 item'
                  : 'Ver mais $hidden itens',
              iconTone: AppIconWellTone.accent,
              onTap: onSeeAll,
              showChevron: true,
            ),
          if (unknown > 0)
            AppListRow(
              icon: Icons.help_outline,
              title: unknownHistoryPhrase(unknown),
              onTap: onUnknownTap,
              showChevron: onUnknownTap != null,
            ),
          ?prompt,
        ],
      );
    }

    // Nothing late or close: one line, not a card. It still answers the
    // question — and when some history is unknown it says so rather than
    // "Tudo em dia", which the app has no grounds to claim.
    final line = _VerdictLine(
      verdict: verdict,
      onTap: switch (verdict.kind) {
        VerdictKind.unknown => onUnknownTap,
        VerdictKind.nothingTracked => onProfileTap,
        _ => null,
      },
    );
    if (prompt == null) return line;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line,
        const SizedBox(height: AppSpacing.s12),
        AppGroup(children: [prompt]),
      ],
    );
  }
}

/// The verdict as one quiet line: a glyph and a sentence, no card.
class _VerdictLine extends StatelessWidget {
  const _VerdictLine({required this.verdict, this.onTap});

  final DashboardVerdict verdict;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);
    final fine = verdict.kind == VerdictKind.fine;
    final glyph = fine ? tones.success : scheme.onSurfaceVariant;

    final line = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          fine ? Icons.check_circle_outline : Icons.help_outline,
          size: 22,
          color: glyph,
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(verdict.phrase, style: theme.textTheme.titleSmall),
              if (verdict.detail != null) ...[
                const SizedBox(height: 2),
                Text(verdict.detail!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (onTap != null)
          Icon(
            Icons.chevron_right,
            size: 20,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
          ),
      ],
    );

    final spoken = verdict.detail == null
        ? verdict.phrase
        : '${verdict.phrase}. ${verdict.detail}';
    if (onTap == null) {
      return Semantics(label: spoken, excludeSemantics: true, child: line);
    }
    return AppListRowShell(onTap: onTap, semanticLabel: spoken, child: line);
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

// ---------------------------------------------------------------- loading

/// The skeleton mirrors the real layout — the car, the reading, a group, two
/// tiles, a group — because the shape of this screen is known before the
/// data arrives, and content that lands where its placeholder was does not
/// make the screen jump.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key, this.header});

  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.s8,
          AppSpacing.page,
          AppSpacing.s40,
        ),
        children: [
          if (header != null) ...[
            header!,
            const SizedBox(height: AppSpacing.s24),
          ] else ...[
            const SizedBox(height: AppSpacing.s4),
            const AppSkeleton(width: 140, height: 30),
            const SizedBox(height: AppSpacing.s12),
            const AppSkeleton(width: 200, height: 18),
            const SizedBox(height: AppSpacing.s24),
          ],
          const AppSkeleton(width: 220, height: 44),
          const SizedBox(height: AppSpacing.s8),
          const AppSkeleton(width: 120, height: 14),
          const SizedBox(height: AppSpacing.block),
          const AppSkeleton(width: double.infinity, height: 132),
          const SizedBox(height: AppSpacing.block),
          const Row(
            children: [
              Expanded(child: AppSkeleton(height: 96)),
              SizedBox(width: AppSpacing.s12),
              Expanded(child: AppSkeleton(height: 96)),
            ],
          ),
          const SizedBox(height: AppSpacing.s32),
          const AppSkeleton(width: double.infinity, height: 180),
        ],
      ),
    );
  }
}
