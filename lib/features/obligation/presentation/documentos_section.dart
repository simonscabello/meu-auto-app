import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/features/obligation/application/obligation_provider.dart';
import 'package:meu_auto/features/obligation/domain/obligation.dart';
import 'package:meu_auto/features/obligation/domain/obligation_copy.dart';
import 'package:meu_auto/features/obligation/domain/seguro.dart';
import 'package:meu_auto/features/obligation/presentation/obligation_form_sheet.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/presentation/vehicle_context_title.dart';
import 'package:meu_auto/shared/widgets/app_bottom_sheet.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_group_scope.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_sheet_header.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_tab_header.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

class DocumentosScreen extends ConsumerWidget {
  const DocumentosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedVehicleProvider);
    final vehicle = selected.valueOrNull;

    return AppScaffold(
      onRefresh: vehicle == null ? null : () => _refresh(ref, vehicle.id),
      body: Column(
        children: [
          VehicleTabHeader(
            title: 'Documentos',
            actions: [
              if (vehicle != null)
                AppIconButton(
                  label: 'Registrar documento',
                  icon: Icons.add,
                  onPressed: () => _chooseKind(context, vehicle.id),
                ),
            ],
          ),
          Expanded(
            child: AppTabBody(
              child: selected.when(
                loading: () => const _DocumentosSkeleton(),
                error: (error, _) => AppErrorState.fromError(
                  error: error,
                  onRetry: () => ref.read(vehiclesProvider.notifier).reload(),
                ),
                data: (current) => current == null
                    ? const SizedBox.shrink()
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: AppSpacing.tab,
                        children: [
                          DocumentosSection(
                            vehicleId: current.id,
                            showHeading: false,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// IPVA, licenciamento or seguro. The rare moment someone adds a
  /// document — a new year's IPVA — so it is one tap behind "+", instead of
  /// three "Registrar" rows standing permanently under the documents.
  Future<void> _chooseKind(BuildContext context, String vehicleId) {
    return showAppSheet<void>(
      context,
      builder: (sheetContext) => SafeArea(
        child: AppSheetBody(
          children: [
            const AppSheetHeader(title: 'Registrar', closable: false),
            const SizedBox(height: AppSpacing.s8),
            AppGroup(
              children: [
                AppListRow(
                  icon: Icons.receipt_long_outlined,
                  title: 'IPVA',
                  showChevron: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ObligationFormSheet.show(
                      context,
                      vehicleId: vehicleId,
                      kind: ObligationKind.ipva,
                    );
                  },
                ),
                AppListRow(
                  icon: Icons.description_outlined,
                  title: 'Licenciamento',
                  showChevron: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ObligationFormSheet.show(
                      context,
                      vehicleId: vehicleId,
                      kind: ObligationKind.licenciamento,
                    );
                  },
                ),
                AppListRow(
                  icon: Icons.shield_outlined,
                  title: 'Seguro',
                  showChevron: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push(AppRoutes.seguroNew);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref, String vehicleId) async {
    ref.invalidate(obligationsProvider(vehicleId));
    ref.invalidate(segurosProvider(vehicleId));
    try {
      await Future.wait([
        ref.read(obligationsProvider(vehicleId).future),
        ref.read(segurosProvider(vehicleId).future),
      ]);
    } on Object {
      // The providers keep the failure and the section renders it.
    }
  }
}

class DocumentosSection extends ConsumerWidget {
  const DocumentosSection({
    super.key,
    required this.vehicleId,
    this.showHeading = true,
  });

  final String vehicleId;
  final bool showHeading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obligations = ref.watch(obligationsProvider(vehicleId));
    final seguros = ref.watch(segurosProvider(vehicleId));

    if ((obligations.isLoading && obligations.value == null) ||
        (seguros.isLoading && seguros.value == null)) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSkeleton(width: 180, height: 14),
            SizedBox(height: AppSpacing.s16),
            AppSkeletonList(count: 3, itemHeight: 56),
          ],
        ),
      );
    }

    final obligationError = obligations.error;
    if (obligationError != null && obligations.value == null) {
      return AppErrorState.fromError(
        error: obligationError,
        onRetry: () => ref.invalidate(obligationsProvider(vehicleId)),
      );
    }
    final seguroError = seguros.error;
    if (seguroError != null && seguros.value == null) {
      return AppErrorState.fromError(
        error: seguroError,
        onRetry: () => ref.invalidate(segurosProvider(vehicleId)),
      );
    }

    return DocumentosContent(
      obligations: obligations.valueOrNull ?? const [],
      seguros: seguros.valueOrNull ?? const [],
      showHeading: showHeading,
      onObligationTap: (obligation) =>
          context.push(AppRoutes.obligation(obligation.id)),
      onRegisterIpva: () => ObligationFormSheet.show(
        context,
        vehicleId: vehicleId,
        kind: ObligationKind.ipva,
      ),
      onRegisterLicenciamento: () => ObligationFormSheet.show(
        context,
        vehicleId: vehicleId,
        kind: ObligationKind.licenciamento,
      ),
      onSeguroTap: (seguro) => context.push(AppRoutes.seguro(seguro.id)),
      onRegisterSeguro: () => context.push(AppRoutes.seguroNew),
    );
  }
}

/// IPVA, licenciamento and seguro, each in its own group.
///
/// The three kinds are separate groups rather than one long list on purpose:
/// they have nothing to do with each other beyond arriving in the same
/// envelope, and a row that says "Nenhum seguro registrado" has to sit under
/// the word Seguro to mean anything. The way to add one is the last row of
/// its group, which reads as "and one more here".
class DocumentosContent extends StatelessWidget {
  const DocumentosContent({
    super.key,
    required this.obligations,
    required this.seguros,
    this.showHeading = true,
    this.onObligationTap,
    this.onRegisterIpva,
    this.onRegisterLicenciamento,
    this.onSeguroTap,
    this.onRegisterSeguro,
  });

  final List<Obligation> obligations;
  final List<Seguro> seguros;
  final bool showHeading;
  final ValueChanged<Obligation>? onObligationTap;
  final VoidCallback? onRegisterIpva;
  final VoidCallback? onRegisterLicenciamento;
  final ValueChanged<Seguro>? onSeguroTap;
  final VoidCallback? onRegisterSeguro;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ipva = obligationsOfKind(obligations, ObligationKind.ipva);
    final licenciamento = obligationsOfKind(
      obligations,
      ObligationKind.licenciamento,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeading)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
            child: Semantics(
              container: true,
              header: true,
              child: Text(
                'Documentos e prazos',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
        AppGroup(
          title: 'IPVA e licenciamento',
          children: [
            for (final obligation in [...ipva, ...licenciamento])
              _ObligationRow(
                key: ValueKey(obligation.id),
                obligation: obligation,
                onTap: onObligationTap == null
                    ? null
                    : () => onObligationTap!(obligation),
              ),
            // A kind with nothing registered keeps a way in right where it
            // would be. Once there is one, the next year's is added from "+".
            if (ipva.isEmpty && onRegisterIpva != null)
              AppListRow(
                icon: Icons.add,
                iconTone: AppIconWellTone.accent,
                title: 'Registrar IPVA',
                onTap: onRegisterIpva,
              ),
            if (licenciamento.isEmpty && onRegisterLicenciamento != null)
              AppListRow(
                icon: Icons.add,
                iconTone: AppIconWellTone.accent,
                title: 'Registrar licenciamento',
                onTap: onRegisterLicenciamento,
              ),
          ],
        ),
        const SizedBox(height: appGroupGap),
        AppGroup(
          title: 'Seguro',
          children: [
            for (final seguro in seguros)
              _SeguroRow(
                key: ValueKey(seguro.id),
                seguro: seguro,
                onTap: onSeguroTap == null ? null : () => onSeguroTap!(seguro),
              ),
            if (seguros.isEmpty && onRegisterSeguro != null)
              AppListRow(
                icon: Icons.add,
                iconTone: AppIconWellTone.accent,
                title: 'Registrar seguro',
                onTap: onRegisterSeguro,
              ),
          ],
        ),
      ],
    );
  }
}

class _DocumentosSkeleton extends StatelessWidget {
  const _DocumentosSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.tab,
      children: const [
        AppSkeleton(width: 170, height: 18),
        SizedBox(height: AppSpacing.s12),
        AppSkeleton(width: double.infinity, height: 132),
        SizedBox(height: AppSpacing.block),
        AppSkeleton(width: 80, height: 18),
        SizedBox(height: AppSpacing.s12),
        AppSkeleton(width: double.infinity, height: 66),
      ],
    );
  }
}

class _ObligationRow extends StatelessWidget with GroupedRow {
  const _ObligationRow({super.key, required this.obligation, this.onTap});

  final Obligation obligation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      icon: obligation.kind == ObligationKind.ipva
          ? Icons.receipt_long_outlined
          : Icons.description_outlined,
      title: obligationTitle(obligation),
      subtitle: obligationListSubtitle(obligation),
      status: AppStatus.fromWire(obligation.status.wire),
      onTap: onTap,
      showChevron: onTap != null,
    );
  }
}

class _SeguroRow extends StatelessWidget with GroupedRow {
  const _SeguroRow({super.key, required this.seguro, this.onTap});

  final Seguro seguro;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // A policy the next one took over from is history, not a warning: its
    // row stays quiet whatever the wire says.
    final status = seguro.renewed
        ? AppStatus.semPeriodicidade
        : AppStatus.fromWire(seguro.status.wire);
    return AppListRow(
      icon: Icons.shield_outlined,
      title: seguro.insurerName,
      subtitle: seguroListSubtitle(seguro),
      status: status,
      onTap: onTap,
      showChevron: onTap != null,
    );
  }
}
