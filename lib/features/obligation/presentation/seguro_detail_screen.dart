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
import 'package:meu_auto/shared/widgets/app_confirm.dart';
import 'package:meu_auto/shared/widgets/app_detail_header.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_fact_row.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_pressable.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';
import 'package:meu_auto/shared/widgets/app_surface.dart';
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
          padding: AppSpacing.screen,
          child: AppSkeletonList(count: 3, itemHeight: 110),
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
    final phrase = seguroStatusPhrase(seguro);
    final emergency = seguro.emergencyPhone?.trim();
    final premium = seguro.premiumCents;
    final policy = seguro.policyNumber?.trim();
    final brokerName = seguro.brokerName?.trim();
    final brokerPhone = seguro.brokerPhone?.trim();
    final notes = seguro.notes?.trim();
    final status = seguro.renewed
        ? AppStatus.semPeriodicidade
        : AppStatus.fromWire(seguro.status.wire);

    return ListView(
      padding: AppSpacing.screenHeaded,
      children: [
        AppDetailHeader(
          icon: Icons.shield_outlined,
          title: seguro.insurerName,
          status: status,
          phrase: phrase,
        ),
        if (emergency != null && emergency.isNotEmpty) ...[
          const SizedBox(height: appGroupGap),
          // The one thing on this screen that is needed at the roadside, and
          // the only raised surface: a tap dials.
          _EmergencyCall(phone: emergency, onTap: onEmergencyCall),
        ],
        const SizedBox(height: appGroupGap),
        AppGroup(
          dividerIndent: 0,
          children: [
            AppFactRow(label: 'Vigência', value: seguroVigenciaPhrase(seguro)),
            if (premium != null)
              AppFactRow(label: 'Prêmio', value: premium.format()),
            if (policy != null && policy.isNotEmpty)
              AppFactRow(label: 'Apólice', value: policy),
            if (brokerName != null && brokerName.isNotEmpty)
              AppFactRow(label: 'Corretor', value: brokerName),
            if (brokerPhone != null && brokerPhone.isNotEmpty)
              AppFactRow(
                label: 'Telefone do corretor',
                value: brokerPhone,
                onTap: onBrokerCall,
              ),
            if (notes != null && notes.isNotEmpty)
              AppFactRow(label: 'Observações', value: notes),
          ],
        ),
        const SizedBox(height: appGroupGap),
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

class _EmergencyCall extends StatelessWidget {
  const _EmergencyCall({required this.phone, this.onTap});

  final String phone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: onTap != null,
      label: 'Emergência. $phone. Ligar',
      excludeSemantics: true,
      child: AppPressable(
        onTap: onTap,
        child: AppSurface(
          variant: AppSurfaceVariant.raised,
          onTap: onTap,
          child: Row(
            children: [
              const AppIconWell(
                icon: Icons.phone_outlined,
                size: AppIconWellSize.l,
                tone: AppIconWellTone.accent,
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergência',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.call_outlined, size: 22, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
