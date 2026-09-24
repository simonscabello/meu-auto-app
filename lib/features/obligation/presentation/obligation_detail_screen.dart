import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/features/obligation/application/obligation_provider.dart';
import 'package:meu_auto/features/obligation/domain/obligation.dart';
import 'package:meu_auto/features/obligation/domain/obligation_copy.dart';
import 'package:meu_auto/features/obligation/presentation/obligation_form_sheet.dart';
import 'package:meu_auto/features/obligation/presentation/obligation_payment_sheet.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';
import 'package:meu_auto/shared/widgets/app_detail_header.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_fact_row.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

class ObligationDetailScreen extends ConsumerWidget {
  const ObligationDetailScreen({super.key, required this.obligationId});

  final String obligationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obligation = ref.watch(obligationProvider(obligationId));

    return obligation.when(
      loading: () => const AppScaffold(
        title: 'Prazo',
        body: Padding(
          padding: AppSpacing.screen,
          child: AppSkeletonList(count: 3, itemHeight: 110),
        ),
      ),
      error: (error, _) => AppScaffold(
        title: 'Prazo',
        body: AppErrorState.fromError(
          error: error,
          onRetry: () => ref.invalidate(obligationProvider(obligationId)),
        ),
      ),
      data: (current) => AppScaffold(
        title: obligationKindLabel(current.kind),
        body: ObligationDetailContent(
          obligation: current,
          onMarkPaid: current.isPaid
              ? null
              : () => ObligationPaymentSheet.show(context, obligation: current),
          onUndoPayment: current.isPaid
              ? () => _clearPayment(context, ref, current)
              : null,
          onEdit: () => ObligationFormSheet.show(
            context,
            vehicleId: current.vehicleId,
            kind: current.kind,
            existing: current,
          ),
          onDelete: () => _delete(context, ref, current),
        ),
      ),
    );
  }
}

Future<void> _clearPayment(
  BuildContext context,
  WidgetRef ref,
  Obligation obligation,
) async {
  final confirmed = await confirmAction(
    context,
    title: 'Desfazer o pagamento?',
    message:
        'O ${obligationKindLabel(obligation.kind).toLowerCase()} volta a '
        'aparecer como pendente.',
    confirmLabel: 'Desfazer pagamento',
  );
  if (!confirmed || !context.mounted) return;

  try {
    await ref
        .read(obligationRepositoryProvider)
        .updateObligation(obligation.id, clearPayment: true);
    invalidateAfterObligationWrite(ref, obligation.vehicleId);
    if (!context.mounted) return;
    showAppSnackBar(
      ScaffoldMessenger.of(context),
      message: 'Pagamento desfeito.',
    );
  } on ApiFailure catch (failure) {
    if (!context.mounted) return;
    showAppErrorSnackBar(
      ScaffoldMessenger.of(context),
      message: ApiFormErrors.bannerOf(failure) ?? failure.message,
    );
  }
}

Future<void> _delete(
  BuildContext context,
  WidgetRef ref,
  Obligation obligation,
) async {
  final label = obligationKindLabel(obligation.kind);
  final confirmed = await confirmAction(
    context,
    title: 'Excluir este $label?',
    message: 'O registro some da lista. Isso não altera nada na receita.',
    confirmLabel: 'Excluir',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    await ref
        .read(obligationRepositoryProvider)
        .deleteObligation(obligation.id);
    invalidateAfterObligationWrite(ref, obligation.vehicleId);
    navigator.pop();
    showAppSnackBar(
      messenger,
      message: obligationDeletedMessage(obligation.kind),
    );
  } on ApiFailure catch (failure) {
    showAppErrorSnackBar(
      messenger,
      message: ApiFormErrors.bannerOf(failure) ?? failure.message,
    );
  }
}

class ObligationDetailContent extends StatelessWidget {
  const ObligationDetailContent({
    super.key,
    required this.obligation,
    this.onMarkPaid,
    this.onUndoPayment,
    this.onEdit,
    this.onDelete,
  });

  final Obligation obligation;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onUndoPayment;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final phrase = obligationStatusPhrase(obligation);
    final amount = obligation.amountCents;
    final paidAmount = obligation.paidAmountCents;
    final showPaidAmount =
        paidAmount != null && (amount == null || paidAmount != amount);

    return ListView(
      padding: AppSpacing.screenHeaded,
      children: [
        AppDetailHeader(
          icon: obligation.kind == ObligationKind.ipva
              ? Icons.receipt_long_outlined
              : Icons.description_outlined,
          title: obligationTitle(obligation),
          status: AppStatus.fromWire(obligation.status.wire),
          phrase: phrase,
        ),
        const SizedBox(height: appGroupGap),
        AppGroup(
          dividerIndent: 0,
          children: [
            AppFactRow(
              label: 'Vencimento',
              value: formatCivilDateLong(obligation.dueOn),
            ),
            if (amount != null)
              AppFactRow(label: 'Valor', value: amount.format()),
            if (obligation.paidOn != null)
              AppFactRow(
                label: 'Pago em',
                value: formatCivilDateLong(obligation.paidOn!),
              ),
            if (showPaidAmount)
              AppFactRow(label: 'Valor pago', value: paidAmount.format()),
            if (obligation.notes != null && obligation.notes!.trim().isNotEmpty)
              AppFactRow(label: 'Observações', value: obligation.notes!.trim()),
          ],
        ),
        const SizedBox(height: appGroupGap),
        if (onMarkPaid != null) ...[
          AppButton(
            label: 'Marcar como pago',
            onPressed: onMarkPaid,
            expanded: true,
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
        if (onUndoPayment != null) ...[
          AppButton(
            label: 'Desfazer pagamento',
            variant: AppButtonVariant.secondary,
            onPressed: onUndoPayment,
            expanded: true,
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
        if (onEdit != null) ...[
          AppButton(
            label: 'Editar',
            icon: Icons.edit_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: onEdit,
            expanded: true,
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
        if (onDelete != null)
          AppButton(
            label: 'Excluir',
            variant: AppButtonVariant.destructive,
            onPressed: onDelete,
            expanded: true,
          ),
      ],
    );
  }
}
