import 'package:flutter/material.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/shared/widgets/app_group_scope.dart';
import 'package:meu_auto/core/domain/phrases.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';

/// One alert as a row.
///
/// Shared by Início and the full list behind its "Ver todos", so the two say
/// the same thing about the same item. The glyph is tinted only for a loud
/// status — red for late, amber for close — and [alertDetailLine] says how
/// late or how close in words, so the colour is never the only signal.
class AlertRow extends StatelessWidget with GroupedRow {
  const AlertRow({super.key, required this.alert, this.onTap, this.icon});

  final Alert alert;
  final VoidCallback? onTap;

  /// The item's own glyph — a tyre, an oil can — when the caller knows it.
  /// Falls back to the glyph of the alert's kind.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = alertStatusOf(alert.severity);
    final visual = statusColors(status, theme.brightness);
    final detail = alertDetailLine(alert);

    return AppListRow(
      icon: icon ?? alertIconOf(alert.kind),
      title: alert.title,
      subtitle: detail ?? visual.label,
      status: status,
      onTap: onTap,
      showChevron: onTap != null,
      semanticLabel: detail == null
          ? '${alert.title}. ${visual.label}'
          : '${alert.title}. $detail',
    );
  }
}

/// The server's own subtitle plus how late or how far, in one line:
/// "Venceu há 13 dias", "Porto Seguro · Vence em 12 dias",
/// "Faltam 2.000 km ou 21/03/2027".
///
/// Never invents a subtitle, and never writes "0 km" for a dimension that came
/// back null — null means the dimension does not apply. A late or close item
/// says only its most urgent dimension: the row is read at a glance, and
/// "venceu há 13 dias · passou 1.200 km" asks the owner to weigh two facts
/// when one decides.
String? alertDetailLine(Alert alert) {
  final parts = <String>[];
  final subtitle = alert.subtitle?.trim();
  if (subtitle != null && subtitle.isNotEmpty) {
    parts.add(subtitle);
  }
  final due = alert.severity == AlertSeverity.emDia
      ? upcomingSummary(
          remainingKm: alert.remainingKm,
          remainingDays: alert.remainingDays,
          dueOn: alert.dueOn,
        )
      : urgencyPhrase(
          remainingKm: alert.remainingKm,
          remainingDays: alert.remainingDays,
        );
  if (due != null) {
    parts.add(due);
  }
  return parts.isEmpty ? null : parts.join(dotSep);
}

IconData alertIconOf(AlertKind kind) {
  return switch (kind) {
    AlertKind.manutencao => Icons.build_outlined,
    AlertKind.cuidado => Icons.checklist_rtl_outlined,
    AlertKind.garantia => Icons.verified_user_outlined,
    AlertKind.ipva => Icons.receipt_long_outlined,
    AlertKind.licenciamento => Icons.description_outlined,
    AlertKind.seguro => Icons.shield_outlined,
    AlertKind.desconhecido => Icons.notifications_none_outlined,
  };
}

AppStatus alertStatusOf(AlertSeverity severity) {
  return switch (severity) {
    AlertSeverity.vencido => AppStatus.vencido,
    AlertSeverity.venceEmBreve => AppStatus.venceEmBreve,
    AlertSeverity.emDia => AppStatus.emDia,
    AlertSeverity.desconhecido => AppStatus.semPeriodicidade,
  };
}

/// Where an alert opens. `reference_type` says where it lives; an unknown one
/// lands on the maintenance tab rather than inventing a screen.
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
