import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/domain/phrases.dart';
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
import 'package:meu_auto/shared/widgets/app_facts_strip.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_overflow_menu.dart';
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
      loading: () =>
          const AppScaffold(title: 'Documento', body: DocumentDetailSkeleton()),
      error: (error, _) => AppScaffold(
        title: 'Documento',
        body: AppErrorState.fromError(
          error: error,
          onRetry: () => ref.invalidate(obligationProvider(obligationId)),
        ),
      ),
      data: (current) => ObligationDetailContent(
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
    message: 'O ${obligationTitle(obligation)} volta a aparecer como a pagar.',
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
  final confirmed = await confirmAction(
    context,
    title: 'Excluir o ${obligationTitle(obligation)}?',
    message: 'Ele sai da lista deste carro. Nada muda fora do app.',
    confirmLabel: 'Excluir ${obligationKindInSentence(obligation.kind)}',
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

/// The sentence beside the badge: when it was paid, or how far the due date
/// is. Every number in it arrived from the server — the delay is the gap
/// between two stored dates, and the days to the due date are
/// `remaining_days`.
String obligationHeaderPhrase(Obligation obligation) {
  switch (obligation.status) {
    case ObligationStatus.pago:
      // The strip already says when it was paid; the line adds only what
      // it does not — that the payment was on time, or how late it was.
      final late = paidLatePhrase(daysPaidLate(obligation) ?? 0);
      if (late != null) return capitalizeFirst(late);
      return obligation.paidOn == null ? '' : 'No prazo';
    case ObligationStatus.vencido:
    case ObligationStatus.venceEmBreve:
    case ObligationStatus.pendente:
      return dueInDaysPhrase(obligation.remainingDays);
    case ObligationStatus.desconhecido:
      return '';
  }
}

/// The IPVA or licenciamento screen as pure presentation, app bar included,
/// so its actions can be tested without a provider scope.
///
/// Its question is "is it paid, and if not, by when and how much". The badge
/// and the phrase answer the first half, the strip the second, and when it is
/// not paid the one filled button is the thing the screen exists for.
/// Editing is the pencil; undoing a payment and deleting are rare, and live
/// in the ⋮.
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

  /// "Registrar pagamento" — the screen's primary action while it is unpaid.
  final VoidCallback? onMarkPaid;
  final VoidCallback? onUndoPayment;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final kind = obligationKindInSentence(obligation.kind);
    final menu = [
      if (onUndoPayment != null)
        AppMenuAction(label: 'Desfazer pagamento', onSelected: onUndoPayment!),
      if (onDelete != null)
        AppMenuAction(
          label: 'Excluir $kind',
          destructive: true,
          onSelected: onDelete!,
        ),
    ];

    return AppScaffold(
      title: obligationKindLabel(obligation.kind),
      actions: [
        if (onEdit != null)
          AppIconButton(
            label: 'Editar $kind',
            icon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
        if (menu.isNotEmpty) AppOverflowMenu(actions: menu),
      ],
      body: _body(),
    );
  }

  Widget _body() {
    final amount = obligation.amountCents;
    final paidAmount = obligation.paidAmountCents;
    final paidOn = obligation.paidOn;
    final notes = obligation.notes?.trim();
    final paid = obligation.isPaid;

    // Paid, the strip says what happened: the due date, the day it was paid
    // and what was paid. The predicted amount then only matters when it was
    // different, and moves to the details.
    final facts = [
      AppFact(label: 'Vencimento', value: formatCivilDate(obligation.dueOn)),
      if (paid && paidOn != null)
        AppFact(label: 'Pago em', value: formatCivilDate(paidOn)),
      if (paid && paidAmount != null)
        AppFact(label: 'Valor pago', value: paidAmount.format())
      else if (amount != null)
        AppFact(label: 'Valor', value: amount.format()),
    ];
    final predicted = paid && paidAmount != null && paidAmount != amount
        ? amount
        : null;
    final details = [
      if (predicted != null)
        AppFactRow(
          label: 'Valor previsto',
          value: predicted.format(),
          inline: true,
        ),
      if (notes != null && notes.isNotEmpty)
        AppFactRow(label: 'Observação', value: notes),
    ];

    return ListView(
      padding: AppSpacing.screenHeaded,
      children: [
        AppDetailHeader(
          title: obligationTitle(obligation),
          status: obligation.status == ObligationStatus.desconhecido
              ? null
              : AppStatus.fromWire(obligation.status.wire),
          phrase: obligationHeaderPhrase(obligation),
        ),
        const SizedBox(height: AppSpacing.s24),
        AppFactsStrip(facts: facts),
        if (onMarkPaid != null) ...[
          const SizedBox(height: AppSpacing.s16),
          AppButton(
            label: 'Registrar pagamento',
            onPressed: onMarkPaid,
            expanded: true,
          ),
        ],
        if (details.isNotEmpty) ...[
          const SizedBox(height: appGroupGap),
          AppGroup(
            title: 'Detalhes',
            dividerIndent: AppGroup.textIndent,
            children: details,
          ),
        ],
      ],
    );
  }
}

/// The shape of a document's detail while it loads: a title, the strip and
/// one group.
class DocumentDetailSkeleton extends StatelessWidget {
  const DocumentDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.screenHeaded,
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        AppSkeleton(width: 180, height: 28),
        SizedBox(height: AppSpacing.s12),
        AppSkeleton(width: 140, height: 20),
        SizedBox(height: AppSpacing.s24),
        AppSkeleton(width: double.infinity, height: 76),
        SizedBox(height: appGroupGap),
        AppSkeleton(width: 90, height: 18),
        SizedBox(height: AppSpacing.s12),
        AppSkeleton(width: double.infinity, height: 104),
      ],
    );
  }
}
