import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/domain/phrases.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/features/obligation/application/obligation_provider.dart';
import 'package:meu_auto/features/obligation/domain/obligation_copy.dart';
import 'package:meu_auto/features/obligation/domain/seguro.dart';
import 'package:meu_auto/features/obligation/presentation/obligation_detail_screen.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';
import 'package:meu_auto/shared/widgets/app_detail_header.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_fact_row.dart';
import 'package:meu_auto/shared/widgets/app_facts_strip.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_group_scope.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_overflow_menu.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

class SeguroDetailScreen extends ConsumerWidget {
  const SeguroDetailScreen({super.key, required this.seguroId});

  final String seguroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seguro = ref.watch(seguroProvider(seguroId));

    return seguro.when(
      loading: () =>
          const AppScaffold(title: 'Seguro', body: DocumentDetailSkeleton()),
      error: (error, _) => AppScaffold(
        title: 'Seguro',
        body: AppErrorState.fromError(
          error: error,
          onRetry: () => ref.invalidate(seguroProvider(seguroId)),
        ),
      ),
      data: (current) => SeguroDetailContent(
        seguro: current,
        onEmergencyCall: current.emergencyPhone == null
            ? null
            : () => _dial(context, current.emergencyPhone!),
        onBrokerCall: current.brokerPhone == null
            ? null
            : () => _dial(context, current.brokerPhone!),
        onEdit: () => context.push(AppRoutes.seguroEdit(current.id)),
        onDelete: () => _delete(context, ref, current),
      ),
    );
  }
}

Future<void> _dial(BuildContext context, String phone) async {
  final uri = telUri(phone);
  final launched = await launchUrl(uri);
  if (launched || !context.mounted) return;
  showAppErrorSnackBar(
    ScaffoldMessenger.of(context),
    message: 'Não foi possível abrir o telefone.',
  );
}

Future<void> _delete(BuildContext context, WidgetRef ref, Seguro seguro) async {
  final confirmed = await confirmAction(
    context,
    title: 'Excluir este seguro?',
    message: 'A apólice sai da lista. Isso não cancela o contrato.',
    confirmLabel: 'Excluir seguro',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    await ref.read(obligationRepositoryProvider).deleteSeguro(seguro.id);
    invalidateAfterSeguroWrite(ref, seguro.vehicleId);
    navigator.pop();
    showAppSnackBar(messenger, message: 'Seguro excluído.');
  } on ApiFailure catch (failure) {
    showAppErrorSnackBar(
      messenger,
      message: ApiFormErrors.bannerOf(failure) ?? failure.message,
    );
  }
}

/// Digits (and a leading +) for a `tel:` link. The number on screen stays
/// as the owner typed it.
Uri telUri(String raw) {
  final buffer = StringBuffer();
  for (final unit in raw.codeUnits) {
    if (unit == 0x2B && buffer.isEmpty) {
      buffer.writeCharCode(unit);
      continue;
    }
    if (unit >= 0x30 && unit <= 0x39) buffer.writeCharCode(unit);
  }
  return Uri(scheme: 'tel', path: buffer.toString());
}

/// The sentence beside the policy's badge. Every count in it is the
/// server's `remaining_days` — to the start while the policy is `futuro`, to
/// the end otherwise.
String seguroHeaderPhrase(Seguro seguro) {
  final late =
      seguro.status == SeguroStatus.vencido ||
      seguro.status == SeguroStatus.venceEmBreve;
  // A policy another one took over from is history, not a warning.
  if (seguro.renewed && late) return 'Substituído pela apólice seguinte';
  return switch (seguro.status) {
    SeguroStatus.futuro => seguroStartsPhrase(seguro.remainingDays),
    SeguroStatus.vigente =>
      seguro.remainingDays > 0 ? dueInDaysPhrase(seguro.remainingDays) : '',
    SeguroStatus.venceEmBreve => dueInDaysPhrase(seguro.remainingDays),
    SeguroStatus.vencido =>
      '${dueInDaysPhrase(seguro.remainingDays)} · carro sem cobertura',
    SeguroStatus.desconhecido => '',
  };
}

/// The policy as pure presentation, app bar included.
///
/// The insurer is the title because it is what the owner calls the policy.
/// The strip answers "until when, and for how much"; the contacts come next
/// because they are what is needed at the roadside, and each number dials.
class SeguroDetailContent extends StatelessWidget {
  const SeguroDetailContent({
    super.key,
    required this.seguro,
    this.onEmergencyCall,
    this.onBrokerCall,
    this.onEdit,
    this.onDelete,
  });

  final Seguro seguro;
  final VoidCallback? onEmergencyCall;
  final VoidCallback? onBrokerCall;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Seguro',
      actions: [
        if (onEdit != null)
          AppIconButton(
            label: 'Editar seguro',
            icon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
        if (onDelete != null)
          AppOverflowMenu(
            actions: [
              AppMenuAction(
                label: 'Excluir seguro',
                destructive: true,
                onSelected: onDelete!,
              ),
            ],
          ),
      ],
      body: _body(),
    );
  }

  Widget _body() {
    final emergency = _text(seguro.emergencyPhone);
    final premium = seguro.premiumCents;
    final policy = _text(seguro.policyNumber);
    final brokerName = _text(seguro.brokerName);
    final brokerPhone = _text(seguro.brokerPhone);
    final notes = _text(seguro.notes);
    final status = seguro.renewed
        ? AppStatus.semPeriodicidade
        : AppStatus.fromWire(seguro.status.wire);

    final contacts = [
      if (emergency != null)
        _CallRow(label: 'Emergência', phone: emergency, onTap: onEmergencyCall),
      if (brokerPhone != null)
        _CallRow(
          label: brokerName == null ? 'Corretor' : 'Corretor · $brokerName',
          phone: brokerPhone,
          onTap: onBrokerCall,
        ),
    ];
    final policyRows = [
      if (policy != null)
        AppFactRow(label: 'Número', value: policy, inline: true),
      AppFactRow(
        label: 'Início',
        value: formatCivilDate(seguro.startsOn),
        inline: true,
      ),
      // A broker with no number to call is a name, and a name is a fact of
      // the policy rather than a contact.
      if (brokerName != null && brokerPhone == null)
        AppFactRow(label: 'Corretor', value: brokerName, inline: true),
      if (notes != null) AppFactRow(label: 'Observação', value: notes),
    ];

    return ListView(
      padding: AppSpacing.screenHeaded,
      children: [
        AppDetailHeader(
          title: seguro.insurerName,
          status: seguro.status == SeguroStatus.desconhecido && !seguro.renewed
              ? null
              : status,
          statusLabel: seguro.renewed ? 'Renovado' : null,
          phrase: seguroHeaderPhrase(seguro),
        ),
        const SizedBox(height: AppSpacing.s24),
        AppFactsStrip(
          facts: [
            AppFact(label: 'Início', value: formatCivilDate(seguro.startsOn)),
            AppFact(label: 'Fim', value: formatCivilDate(seguro.endsOn)),
            if (premium != null)
              AppFact(label: 'Prêmio', value: premium.format()),
          ],
        ),
        if (contacts.isNotEmpty) ...[
          const SizedBox(height: appGroupGap),
          AppGroup(title: 'Contatos', children: contacts),
        ],
        const SizedBox(height: appGroupGap),
        AppGroup(
          title: 'Apólice',
          dividerIndent: AppGroup.textIndent,
          children: policyRows,
        ),
      ],
    );
  }
}

String? _text(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

/// A number that dials when tapped: the number itself in the accent, since
/// it is the thing being pressed, and whose it is underneath.
class _CallRow extends StatelessWidget with GroupedRow {
  const _CallRow({required this.label, required this.phone, this.onTap});

  final String label;
  final String phone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      icon: Icons.phone_outlined,
      iconTone: onTap == null ? null : AppIconWellTone.accent,
      title: phone,
      subtitle: label,
      onTap: onTap,
      semanticLabel: '$label. $phone. Ligar',
    );
  }
}
