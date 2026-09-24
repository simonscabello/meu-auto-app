import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/dashboard/application/dashboard_provider.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';
import 'package:meu_auto/features/dashboard/presentation/alert_row.dart';
import 'package:meu_auto/shared/widgets/app_empty_state.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

/// Everything on the car that needs attention, from every domain.
///
/// The verdict on Início counts maintenance, IPVA, licenciamento, seguro and
/// warranties together, but its "Ver todos" used to open the maintenance tab,
/// which lists only maintenance: "2 itens vencidos" could open a list with
/// one. This is the list the count is about, in the order the server
/// ranked it.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsProvider(vehicleId));

    return AppScaffold(
      title: 'Precisa de atenção',
      onRefresh: () async {
        ref.invalidate(alertsProvider(vehicleId));
        try {
          await ref.read(alertsProvider(vehicleId).future);
        } on Object {
          // The provider holds the failure and the body renders it.
        }
      },
      body: alerts.when(
        skipLoadingOnReload: true,
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.s16),
          child: AppSkeletonList(),
        ),
        error: (error, _) => AppErrorState.fromError(
          error: error,
          onRetry: () => ref.invalidate(alertsProvider(vehicleId)),
        ),
        data: (list) => AlertsContent(
          alerts: list,
          onAlertTap: (alert) {
            final route = routeForAlert(alert);
            if (route == AppRoutes.care) {
              context.go(route);
            } else {
              context.push(route);
            }
          },
        ),
      ),
    );
  }
}

/// The list as pure presentation: what is late, then what is close.
class AlertsContent extends StatelessWidget {
  const AlertsContent({super.key, required this.alerts, this.onAlertTap});

  final List<Alert> alerts;
  final ValueChanged<Alert>? onAlertTap;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const AppEmptyState(
        title: 'Nada precisa de atenção agora',
        message: 'Quando algo vencer ou estiver perto, aparece aqui.',
      );
    }
    final overdue = [
      for (final alert in alerts)
        if (alert.severity == AlertSeverity.vencido) alert,
    ];
    final soon = [
      for (final alert in alerts)
        if (alert.severity != AlertSeverity.vencido) alert,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s16,
        AppSpacing.s32,
      ),
      children: [
        if (overdue.isNotEmpty) ...[
          AppGroup(
            title: 'Vencidos',
            count: overdue.length > 1 ? overdue.length : null,
            children: [
              for (final alert in overdue)
                AlertRow(
                  alert: alert,
                  onTap: onAlertTap == null ? null : () => onAlertTap!(alert),
                ),
            ],
          ),
          const SizedBox(height: appGroupGap),
        ],
        if (soon.isNotEmpty)
          AppGroup(
            title: 'Vencem em breve',
            count: soon.length > 1 ? soon.length : null,
            children: [
              for (final alert in soon)
                AlertRow(
                  alert: alert,
                  onTap: onAlertTap == null ? null : () => onAlertTap!(alert),
                ),
            ],
          ),
      ],
    );
  }
}
