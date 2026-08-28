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
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

class DocumentosSection extends ConsumerWidget {
  const DocumentosSection({super.key, required this.vehicleId});

  final String vehicleId;

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
            AppSkeletonList(count: 3, itemHeight: 44),
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
      obligations: obligations.value ?? const [],
      seguros: seguros.value ?? const [],
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
/// IPVA, licenciamento and seguro, at the foot of Cuidados.
///
/// Same shape as the plans above it — a quiet label, then its rows inside one
/// surface — because it is the same kind of question: what is coming, and
/// what have I not done yet. It used to be three blocks of cards, each ending
/// in its own filled button, so a car with no documents registered showed
/// three primary CTAs stacked and the screen had four things claiming to be
/// the main action.
///
/// The way to add one is the last row of its own group, which reads as "and
/// one more here" and cannot overflow the way a header button does when the
/// label is "Registrar licenciamento" at a large text scale.
///
/// The three kinds are separate groups rather than one long list on purpose:
/// IPVA, licenciamento and seguro have nothing to do with each other beyond
/// arriving in the same envelope, and a row that says "Nenhum seguro
/// registrado" has to sit under the word Seguro to mean anything.
class DocumentosContent extends StatelessWidget {
  const DocumentosContent({
    super.key,
    required this.obligations,
    required this.seguros,
    this.onObligationTap,
    this.onRegisterIpva,
    this.onRegisterLicenciamento,
    this.onSeguroTap,
    this.onRegisterSeguro,
  });

  final List<Obligation> obligations;
  final List<Seguro> seguros;
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
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s12),
          child: Semantics(
            header: true,
            child: Text(
              'Documentos e prazos',
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
        _KindGroup(
          title: 'IPVA',
          emptyTitle: 'Nenhum IPVA registrado',
          emptyMessage: 'Registre o IPVA deste ano para acompanhar o prazo.',
          actionLabel: 'Registrar IPVA',
          onRegister: onRegisterIpva,
          rows: [
            for (final obligation in ipva)
              _ObligationRow(
                key: ValueKey(obligation.id),
                obligation: obligation,
                onTap: onObligationTap == null
                    ? null
                    : () => onObligationTap!(obligation),
              ),
          ],
        ),
        const SizedBox(height: appGroupGap),
        _KindGroup(
          title: 'Licenciamento',
          emptyTitle: 'Nenhum licenciamento registrado',
          emptyMessage:
              'Registre o licenciamento deste ano para acompanhar o prazo.',
          actionLabel: 'Registrar licenciamento',
          onRegister: onRegisterLicenciamento,
          rows: [
            for (final obligation in licenciamento)
              _ObligationRow(
                key: ValueKey(obligation.id),
                obligation: obligation,
                onTap: onObligationTap == null
                    ? null
                    : () => onObligationTap!(obligation),
              ),
          ],
        ),
        const SizedBox(height: appGroupGap),
        _KindGroup(
          title: 'Seguro',
          emptyTitle: 'Nenhum seguro registrado',
          emptyMessage: 'Registre a apólice para acompanhar a vigência.',
          actionLabel: 'Registrar seguro',
          onRegister: onRegisterSeguro,
          rows: [
            for (final seguro in seguros)
              _SeguroRow(
                key: ValueKey(seguro.id),
                seguro: seguro,
                onTap: onSeguroTap == null ? null : () => onSeguroTap!(seguro),
              ),
          ],
        ),
      ],
    );
  }
}

/// One document kind: its label, and either its rows or the sentence saying
/// there are none — always ending with the row that adds one.
class _KindGroup extends StatelessWidget {
  const _KindGroup({
    required this.title,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.actionLabel,
    required this.rows,
    this.onRegister,
  });

  final String title;
  final String emptyTitle;
  final String emptyMessage;
  final String actionLabel;
  final List<Widget> rows;
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppGroup(
      title: title,
      children: [
        if (rows.isEmpty)
          AppListRowShell(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emptyTitle, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(
                  emptyMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          ...rows,
        if (onRegister != null)
          AppListRow(icon: Icons.add, title: actionLabel, onTap: onRegister),
      ],
    );
  }
}

class _ObligationRow extends StatelessWidget {
  const _ObligationRow({super.key, required this.obligation, this.onTap});

  final Obligation obligation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final visual = statusColors(
      AppStatus.fromWire(obligation.status.wire),
      Theme.of(context).brightness,
    );
    final overdue = obligation.status == ObligationStatus.vencido;

    return AppListRow(
      icon: obligation.kind == ObligationKind.ipva
          ? Icons.receipt_long_outlined
          : Icons.description_outlined,
      title: obligationTitle(obligation),
      subtitle: obligationListSubtitle(obligation),
      accent: overdue ? visual.foreground : null,
      onTap: onTap,
      showChevron: onTap != null,
    );
  }
}

class _SeguroRow extends StatelessWidget {
  const _SeguroRow({super.key, required this.seguro, this.onTap});

  final Seguro seguro;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final visual = statusColors(
      AppStatus.fromWire(seguro.status.wire),
      Theme.of(context).brightness,
    );
    final overdue = seguro.status == SeguroStatus.vencido;

    return AppListRow(
      icon: Icons.shield_outlined,
      title: seguro.insurerName,
      subtitle: seguroListSubtitle(seguro),
      accent: overdue ? visual.foreground : null,
      onTap: onTap,
      showChevron: onTap != null,
    );
  }
}
