import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_profile_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_profile.dart';
import 'package:meu_auto/features/maintenance/domain/plan_update.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_icons.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_card.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';

/// "O que o seu carro tem" — the one place the personalisation is visible and
/// reversible.
///
/// Everywhere else, an item the vehicle does not have is simply absent. Here it
/// is listed, because the owner has to be able to disagree with us: they are the
/// one looking at the car.
class VehicleProfileScreen extends ConsumerWidget {
  const VehicleProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(selectedVehicleProvider).value;
    if (vehicle == null) {
      return const AppScaffold(title: 'Seu carro', body: SizedBox.shrink());
    }
    return AppScaffold(
      title: 'Seu carro',
      body: VehicleProfileView(vehicleId: vehicle.id),
    );
  }
}

/// Owns loading, error and content — the same shape every read screen here uses.
class VehicleProfileView extends ConsumerWidget {
  const VehicleProfileView({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(maintenanceProfileProvider(vehicleId));
    final hidden = ref.watch(maintenancePlansWithHiddenProvider(vehicleId));

    return profile.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.s16),
        child: AppSkeletonList(count: 3, itemHeight: 120),
      ),
      error: (error, _) => AppErrorState.fromError(
        error: error,
        onRetry: () => ref.invalidate(maintenanceProfileProvider(vehicleId)),
      ),
      data: (data) => VehicleProfileContent(
        profile: data,
        notApplicable: _notApplicableOf(hidden),
        onAnswer: (question, answer) =>
            unawaited(_answer(context, ref, vehicleId, question, answer)),
        onRestore: (plan) => unawaited(_restore(context, ref, vehicleId, plan)),
        onFixFuel: () => context.push(AppRoutes.vehicleEdit(vehicleId)),
      ),
    );
  }

  List<MaintenancePlan> _notApplicableOf(
    AsyncValue<List<MaintenancePlan>> plans,
  ) {
    // valueOrNull, not value: an AsyncError rethrows from `value`, and this
    // list is the secondary half of the screen. Losing it must not take the
    // questions — the actionable half — down with it.
    final list = plans.valueOrNull;
    if (list == null) return const [];
    return [
      for (final plan in list)
        if (plan.status == MaintenanceStatus.naoSeAplica) plan,
    ];
  }

  Future<void> _answer(
    BuildContext context,
    WidgetRef ref,
    String vehicleId,
    String question,
    String answer,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(maintenanceProfileRepositoryProvider)
          .answer(vehicleId, question: question, answer: answer);
      invalidateAfterProfileWrite(ref, vehicleId);
      showAppSnackBar(messenger, message: 'Anotado.');
    } on ApiFailure catch (failure) {
      showAppSnackBar(
        messenger,
        message: ApiFormErrors.bannerOf(failure) ?? failure.message,
      );
    }
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    String vehicleId,
    MaintenancePlan plan,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(maintenancePlanRepositoryProvider)
          .update(
            plan.id,
            PlanUpdate.applicability(
              strategy: plan.intervalKm != null || plan.intervalMonths != null
                  ? MaintenanceStrategy.periodic
                  : MaintenanceStrategy.noSchedule,
            ),
          );
      invalidateAfterProfileWrite(ref, vehicleId);
      showAppSnackBar(
        messenger,
        message: '${plan.itemName} voltou para a lista.',
      );
    } on ApiFailure catch (failure) {
      showAppSnackBar(
        messenger,
        message: ApiFormErrors.bannerOf(failure) ?? failure.message,
      );
    }
  }
}

/// The profile as pure presentation. No providers, so the copy is testable.
class VehicleProfileContent extends StatelessWidget {
  const VehicleProfileContent({
    super.key,
    required this.profile,
    required this.notApplicable,
    this.onAnswer,
    this.onRestore,
    this.onFixFuel,
  });

  final MaintenanceProfile profile;
  final List<MaintenancePlan> notApplicable;
  final void Function(String question, String answer)? onAnswer;
  final ValueChanged<MaintenancePlan>? onRestore;
  final VoidCallback? onFixFuel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        if (profile.status == MaintenanceProfileStatus.unknown)
          AppCard(
            child: Text(
              'Ainda não temos um plano para este carro. '
              'Você pode adicionar o que quiser acompanhar em Cuidados.',
              style: theme.textTheme.bodyLarge,
            ),
          ),

        // The one gap that blocks everything about the engine. It is not a
        // profile question, because the answer lives on the vehicle itself.
        if (!profile.powertrainKnown) ...[
          const SizedBox(height: AppSpacing.s8),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Qual o combustível do seu carro?',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'É o que diz o que o seu carro tem e o que ele não tem. '
                  'Sem essa resposta a gente não chuta.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                AppButton(
                  label: 'Informar',
                  variant: AppButtonVariant.secondary,
                  onPressed: onFixFuel,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
        ],

        for (final question in profile.questions) ...[
          const SizedBox(height: AppSpacing.s8),
          _QuestionCard(
            question: question,
            onAnswer: onAnswer == null
                ? null
                : (answer) => onAnswer!(question.id, answer),
          ),
        ],

        if (profile.questions.isEmpty && profile.powertrainKnown) ...[
          const SizedBox(height: AppSpacing.s8),
          AppCard(
            child: Text(
              'Não falta nada por aqui. Os cuidados que aparecem no app são os '
              'que fazem sentido para este carro.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],

        if (notApplicable.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s24),
          const AppSectionHeader(title: 'Seu carro não usa'),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Não mostramos esses itens em lugar nenhum. Se algum estiver '
            'errado, é só trazer de volta.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          for (final plan in notApplicable) ...[
            AppCard(
              child: Row(
                children: [
                  Icon(
                    maintenanceIconFor(plan.itemSlug),
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan.itemName, style: theme.textTheme.titleSmall),
                        if (plan.notes != null) ...[
                          const SizedBox(height: AppSpacing.s4),
                          Text(
                            plan.notes!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AppButton(
                    label: 'Tem sim',
                    variant: AppButtonVariant.tertiary,
                    onPressed: onRestore == null
                        ? null
                        : () => onRestore!(plan),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
        ],
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question, this.onAnswer});

  final MaintenanceProfileQuestion question;
  final ValueChanged<String>? onAnswer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question.prompt, style: theme.textTheme.titleSmall),
          if (question.help.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(
              question.help,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s12),
          // Every option the server offered, in the order it offered them —
          // including "não sei", which is a real answer and is never buried.
          for (final option in question.options) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onAnswer == null
                    ? null
                    : () => onAnswer!(option.value),
                child: Text(option.label),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
        ],
      ),
    );
  }
}
