import 'package:flutter/material.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/presentation/care_periodicity_sheet.dart';
import 'package:meu_auto/features/maintenance/presentation/plan_interval_sheet.dart';

Future<void> showPlanPeriodicitySheet(
  BuildContext context, {
  required String vehicleId,
  required MaintenancePlan plan,
}) {
  if (plan.itemKind == MaintenanceItemKind.care) {
    return CarePeriodicitySheet.show(
      context,
      vehicleId: vehicleId,
      plan: plan,
    );
  }
  return PlanIntervalSheet.show(context, vehicleId: vehicleId, plan: plan);
}
