import 'package:flutter/material.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/domain/phrases.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';

/// One alert — or one "what comes next" item — as a row.
///
/// Shared by Início and the full list behind its "Ver todos", so the two say
/// the same thing about the same item. The status chip that used to sit here
/// is gone: the group above says what the list is, [alertDetailLine] says how
/// late or how close in words, and the tint on an overdue icon is the third
/// signal, never the only one.
class AlertRow extends StatelessWidget {
  const AlertRow({super.key, required this.alert, this.onTap});

  final Alert alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = statusColors(
      alertStatusOf(alert.severity),
      theme.brightness,
    );
    final overdue = alert.severity == AlertSeverity.vencido;
    final detail = alertDetailLine(alert);

    return AppListRow(
      icon: alertIconOf(alert.kind),
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
}

/// The server's own subtitle plus the figures it computed, in one line.
///
/// Never invents a subtitle, and never writes "0 km" for a dimension that came
/// back null — null means the dimension does not apply. An upcoming item that
/// is still far away is said as how far, not as a status word.
@visibleForTesting
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
      : dueSummary(
          remainingKm: alert.remainingKm,
          remainingDays: alert.remainingDays,
        );
  if (due != null) {
    parts.add(due);
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

IconData alertIconOf(AlertKind kind) {
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

/// Upcoming, as the distance to it: "em 4.200 km", "em 10/03/2027", or both.
///
/// Uses the figures the server computed. The date is written as a date once
/// it is more than about a month and a half out, because "faltam 197 dias"
/// makes the owner do arithmetic the calendar already did.
@visibleForTesting
String? upcomingSummary({
  int? remainingKm,
  int? remainingDays,
  CivilDate? dueOn,
}) {
  final parts = <String>[];
  if (remainingKm != null && remainingKm > 0) {
    parts.add('em ${formatKm(remainingKm)}');
  }
  if (remainingDays != null && remainingDays >= 0) {
    if (remainingDays > 45 && dueOn != null) {
      parts.add('em ${formatCivilDate(dueOn)}');
    } else {
      final days = remainingDaysPhrase(remainingDays);
      if (days != null) parts.add(days);
    }
  }
  if (parts.isEmpty) return null;
  return parts.join(' ou ');
}
