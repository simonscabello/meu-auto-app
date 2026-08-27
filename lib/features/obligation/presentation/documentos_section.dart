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
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_card.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_status_chip.dart';

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
            AppSkeleton(width: 200, height: 24),
            SizedBox(height: AppSpacing.s12),
            AppSkeletonList(count: 3, itemHeight: 88),
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
    final ipva = obligationsOfKind(obligations, ObligationKind.ipva);
    final licenciamento = obligationsOfKind(
      obligations,
      ObligationKind.licenciamento,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.s8),
        const AppSectionHeader(title: 'Documentos e prazos'),
        const SizedBox(height: AppSpacing.s8),
        _KindBlock(
          title: 'IPVA',
          emptyTitle: 'Nenhum IPVA registrado',
          emptyMessage: 'Registre o IPVA deste ano para acompanhar o prazo.',
          actionLabel: 'Registrar IPVA',
          onRegister: onRegisterIpva,
          children: [
            for (final obligation in ipva) ...[
              _ObligationTile(
                obligation: obligation,
                onTap: onObligationTap == null
                    ? null
                    : () => onObligationTap!(obligation),
              ),
              const SizedBox(height: AppSpacing.s8),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        _KindBlock(
          title: 'Licenciamento',
          emptyTitle: 'Nenhum licenciamento registrado',
          emptyMessage:
              'Registre o licenciamento deste ano para acompanhar o prazo.',
          actionLabel: 'Registrar licenciamento',
          onRegister: onRegisterLicenciamento,
          children: [
            for (final obligation in licenciamento) ...[
              _ObligationTile(
                obligation: obligation,
                onTap: onObligationTap == null
                    ? null
                    : () => onObligationTap!(obligation),
              ),
              const SizedBox(height: AppSpacing.s8),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        _KindBlock(
          title: 'Seguro',
          emptyTitle: 'Nenhum seguro registrado',
          emptyMessage: 'Registre a apólice para acompanhar a vigência.',
          actionLabel: 'Registrar seguro',
          onRegister: onRegisterSeguro,
          children: [
            for (final seguro in seguros) ...[
              _SeguroTile(
                seguro: seguro,
                onTap: onSeguroTap == null ? null : () => onSeguroTap!(seguro),
              ),
              const SizedBox(height: AppSpacing.s8),
            ],
          ],
        ),
      ],
    );
  }
}

class _KindBlock extends StatelessWidget {
  const _KindBlock({
    required this.title,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.actionLabel,
    required this.children,
    this.onRegister,
  });

  final String title;
  final String emptyTitle;
  final String emptyMessage;
  final String actionLabel;
  final List<Widget> children;
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return _KindEmpty(
        title: emptyTitle,
        message: emptyMessage,
        actionLabel: actionLabel,
        onAction: onRegister,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: onRegister == null ? null : 'Registrar',
          onAction: onRegister,
        ),
        const SizedBox(height: AppSpacing.s8),
        ...children,
      ],
    );
  }
}

class _KindEmpty extends StatelessWidget {
  const _KindEmpty({
    required this.title,
    required this.message,
    required this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.s4),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (onAction != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(label: actionLabel, onPressed: onAction),
            ),
          ],
        ],
      ),
    );
  }
}

class _ObligationTile extends StatelessWidget {
  const _ObligationTile({required this.obligation, this.onTap});

  final Obligation obligation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phrase = obligationStatusPhrase(obligation);
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(obligationTitle(obligation), style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.s4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s4,
            children: [
              AppStatusChip(status: AppStatus.fromWire(obligation.status.wire)),
              if (phrase.isNotEmpty)
                Text(
                  phrase,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeguroTile extends StatelessWidget {
  const _SeguroTile({required this.seguro, this.onTap});

  final Seguro seguro;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phrase = seguroStatusPhrase(seguro);
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(seguro.insurerName, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.s4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s4,
            children: [
              AppStatusChip(status: AppStatus.fromWire(seguro.status.wire)),
              if (phrase.isNotEmpty)
                Text(
                  phrase,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
