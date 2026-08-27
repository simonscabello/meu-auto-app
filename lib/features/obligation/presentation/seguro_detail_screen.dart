import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/features/obligation/application/obligation_provider.dart';
import 'package:meu_auto/features/obligation/domain/obligation_copy.dart';
import 'package:meu_auto/features/obligation/domain/seguro.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_card.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';
import 'package:meu_auto/shared/widgets/app_status_chip.dart';
import 'package:url_launcher/url_launcher.dart';

class SeguroDetailScreen extends ConsumerWidget {
  const SeguroDetailScreen({super.key, required this.seguroId});

  final String seguroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seguro = ref.watch(seguroProvider(seguroId));

    return seguro.when(
      loading: () => const AppScaffold(
        title: 'Seguro',
        body: Padding(
          padding: EdgeInsets.all(AppSpacing.s16),
          child: AppSkeletonList(count: 4, itemHeight: 88),
        ),
      ),
      error: (error, _) => AppScaffold(
        title: 'Seguro',
        body: AppErrorState.fromError(
          error: error,
          onRetry: () => ref.invalidate(seguroProvider(seguroId)),
        ),
      ),
      data: (current) => AppScaffold(
        title: 'Seguro',
        body: SeguroDetailContent(
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
    confirmLabel: 'Excluir',
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
    final theme = Theme.of(context);
    final phrase = seguroStatusPhrase(seguro);
    final emergency = seguro.emergencyPhone;
    final premium = seguro.premiumCents;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        Text(seguro.insurerName, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s4,
          children: [
            AppStatusChip(status: AppStatus.fromWire(seguro.status.wire)),
            if (phrase.isNotEmpty)
              Text(
                phrase,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s24),
        _Fact(label: 'Vigência', value: seguroVigenciaPhrase(seguro)),
        if (premium != null) ...[
          const SizedBox(height: AppSpacing.s16),
          _Fact(label: 'Prêmio', value: premium.format()),
        ],
        if (emergency != null && emergency.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s24),
          AppCard(
            onTap: onEmergencyCall,
            child: Row(
              children: [
                Icon(Icons.phone, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emergência',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(emergency, style: theme.textTheme.titleMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (seguro.brokerName != null &&
            seguro.brokerName!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s16),
          _Fact(label: 'Corretor', value: seguro.brokerName!.trim()),
        ],
        if (seguro.brokerPhone != null &&
            seguro.brokerPhone!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s16),
          _Fact(
            label: 'Telefone do corretor',
            value: seguro.brokerPhone!.trim(),
            onTap: onBrokerCall,
          ),
        ],
        if (seguro.policyNumber != null &&
            seguro.policyNumber!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s16),
          _Fact(label: 'Apólice', value: seguro.policyNumber!.trim()),
        ],
        if (seguro.notes != null && seguro.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s16),
          _Fact(label: 'Observações', value: seguro.notes!.trim()),
        ],
        const SizedBox(height: AppSpacing.s32),
        if (onEdit != null) ...[
          AppButton(label: 'Editar', onPressed: onEdit),
          const SizedBox(height: AppSpacing.s8),
        ],
        if (onDelete != null)
          AppButton(
            label: 'Excluir',
            variant: AppButtonVariant.destructive,
            onPressed: onDelete,
          ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: onTap == null ? null : theme.colorScheme.primary,
          ),
        ),
      ],
    );
    if (onTap == null) return column;
    return InkWell(onTap: onTap, child: column);
  }
}
