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
import 'package:meu_auto/features/maintenance/domain/plan_copy.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_icons.dart';
import 'package:meu_auto/features/maintenance/presentation/plan_create_sheet.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
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
    final plans = _splitPlans(
      ref.watch(maintenancePlansWithHiddenProvider(vehicleId)),
    );

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
        inUse: plans.inUse,
        notApplicable: plans.notApplicable,
        onAnswer: (question, answer) =>
            unawaited(_answer(context, ref, vehicleId, question, answer)),
        onRestore: (plan) => unawaited(_restore(context, ref, vehicleId, plan)),
        onFixFuel: () => context.push(AppRoutes.vehicleEdit(vehicleId)),
        onPlanTap: (plan) => context.push(AppRoutes.plan(plan.id)),
        onAddPlan: () => PlanCreateSheet.show(context, vehicleId: vehicleId),
      ),
    );
  }

  /// Splits the one list that carries both halves of this screen.
  ///
  /// `maintenancePlansWithHiddenProvider` is the only provider that returns
  /// the items the vehicle does not use, so it already contains the items it
  /// does. Watching the personalised list as well would be a second request
  /// for a subset of what is already on the screen.
  ///
  /// valueOrNull, not value: an AsyncError rethrows from `value`, and these
  /// lists are the descriptive half of the screen. Losing them must not take
  /// the questions — the actionable half — down too.
  ({List<MaintenancePlan> inUse, List<MaintenancePlan> notApplicable})
  _splitPlans(AsyncValue<List<MaintenancePlan>> plans) {
    final list = plans.valueOrNull;
    if (list == null) return (inUse: const [], notApplicable: const []);
    return (
      inUse: [
        for (final plan in list)
          if (plan.status != MaintenanceStatus.naoSeAplica) plan,
      ],
      notApplicable: [
        for (final plan in list)
          if (plan.status == MaintenanceStatus.naoSeAplica) plan,
      ],
    );
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
///
/// The screen is named "O que o seu carro tem", and for a while it did not
/// answer that: with the fuel known and no question open it rendered one grey
/// sentence saying there was nothing to do, which reads as a screen that
/// failed to load. What was missing is the obvious half — **the list of items
/// this car actually uses**. That list is the whole reason someone opens
/// this screen: to check whether the app has the right idea of their car.
///
/// So it descends in that order: what is still unknown and can be answered,
/// what the car uses, what it does not.
class VehicleProfileContent extends StatelessWidget {
  const VehicleProfileContent({
    super.key,
    required this.profile,
    required this.inUse,
    required this.notApplicable,
    this.onAnswer,
    this.onRestore,
    this.onFixFuel,
    this.onPlanTap,
    this.onAddPlan,
  });

  final MaintenanceProfile profile;

  /// Every item this vehicle is tracked for, whatever its due state. Ordered
  /// by the server.
  final List<MaintenancePlan> inUse;

  final List<MaintenancePlan> notApplicable;
  final void Function(String question, String answer)? onAnswer;
  final ValueChanged<MaintenancePlan>? onRestore;
  final VoidCallback? onFixFuel;
  final ValueChanged<MaintenancePlan>? onPlanTap;
  final VoidCallback? onAddPlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s32,
      ),
      children: [
        if (profile.status == MaintenanceProfileStatus.unknown) ...[
          Text(
            'Ainda não temos um plano para este carro. '
            'Você escolhe o que quer acompanhar.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: appGroupGap),
        ],

        // The one gap that blocks everything about the engine. It is not a
        // profile question, because the answer lives on the vehicle itself.
        if (!profile.powertrainKnown) ...[
          AppGroup(
            children: [
              AppListRowShell(
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppButton(
                        label: 'Informar',
                        variant: AppButtonVariant.secondary,
                        onPressed: onFixFuel,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: appGroupGap),
        ],

        for (final question in profile.questions) ...[
          _QuestionCard(
            question: question,
            onAnswer: onAnswer == null
                ? null
                : (answer) => onAnswer!(question.id, answer),
          ),
          const SizedBox(height: appGroupGap),
        ],

        // The answer to the question in the title, and the reason to open
        // this screen at all.
        AppGroup(
          title: 'Seu carro usa',
          subtitle: inUse.isEmpty
              ? null
              : 'Estes são os itens que o Meu Auto acompanha neste carro.',
          // No count beside the label: the list is right there and short
          // enough to see. A number earns its place when it is the reason not
          // to open something, which is never true of a group already open.
          children: [
            for (final plan in inUse)
              AppListRow(
                key: ValueKey(plan.id),
                icon: maintenanceIconFor(plan.itemSlug),
                title: plan.itemName,
                subtitle: planListSubtitle(plan),
                onTap: onPlanTap == null ? null : () => onPlanTap!(plan),
                showChevron: onPlanTap != null,
              ),
            if (onAddPlan != null)
              AppListRow(
                icon: Icons.add,
                title: 'Acompanhar outro item',
                onTap: onAddPlan,
                showChevron: true,
              ),
          ],
        ),

        if (notApplicable.isNotEmpty) ...[
          const SizedBox(height: appGroupGap),
          AppGroup(
            title: 'Seu carro não usa',
            subtitle:
                'Não mostramos esses itens em lugar nenhum. Se algum estiver '
                'errado, é só trazer de volta.',
            children: [
              for (final plan in notApplicable)
                AppListRow(
                  key: ValueKey(plan.id),
                  icon: maintenanceIconFor(plan.itemSlug),
                  title: plan.itemName,
                  subtitle: plan.notes,
                  trailing: AppButton(
                    label: 'Tem sim',
                    variant: AppButtonVariant.tertiary,
                    onPressed: onRestore == null
                        ? null
                        : () => onRestore!(plan),
                  ),
                ),
            ],
          ),
        ],

        if (profile.questions.isEmpty && profile.powertrainKnown) ...[
          const SizedBox(height: appGroupGap),
          Text(
            'Não falta nada por aqui. Os cuidados que aparecem no app são os '
            'que fazem sentido para este carro.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// One question the server wrote, with the answers it offered.
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question, this.onAnswer});

  final MaintenanceProfileQuestion question;
  final ValueChanged<String>? onAnswer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppGroup(
      children: [
        AppListRowShell(
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
              // Every option the server offered, in the order it offered them
              // — including "não sei", which is a real answer and is never
              // buried.
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
        ),
      ],
    );
  }
}
