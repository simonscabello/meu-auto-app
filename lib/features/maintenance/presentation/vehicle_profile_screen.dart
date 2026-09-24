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
import 'package:meu_auto/features/maintenance/domain/plan_copy.dart';
import 'package:meu_auto/features/maintenance/domain/plan_update.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_icons.dart';
import 'package:meu_auto/features/maintenance/presentation/plan_create_sheet.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_icon_well.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_scaffold.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';
import 'package:meu_auto/shared/widgets/app_snackbar.dart';
import 'package:meu_auto/shared/widgets/app_surface.dart';

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
    final vehicle = ref.watch(selectedVehicleProvider).valueOrNull;
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
        padding: AppSpacing.screen,
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
        onAnswer: (question, answer) => unawaited(
          answerProfileQuestion(context, ref, vehicleId, question, answer),
        ),
        onRestore: (plan) => unawaited(_restore(context, ref, vehicleId, plan)),
        onFixFuel: () => context.push(AppRoutes.vehicleEdit(vehicleId)),
        onPlanTap: (plan) => context.push(AppRoutes.plan(plan.id)),
        onAddPlan: () => PlanCreateSheet.show(context, vehicleId: vehicleId),
      ),
    );
  }

  /// Splits the one list that carries both halves of this screen.
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
/// It descends in this order: what is still unknown and can be answered,
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
    final scheme = theme.colorScheme;

    return ListView(
      padding: AppSpacing.screenHeaded,
      children: [
        if (profile.status == MaintenanceProfileStatus.unknown) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Text(
              'Ainda não temos um plano para este carro. '
              'Você escolhe o que quer acompanhar.',
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: appGroupGap),
        ],

        // The one gap that blocks everything about the engine. It is not a
        // profile question, because the answer lives on the vehicle itself.
        if (!profile.powertrainKnown) ...[
          AppSurface(
            variant: AppSurfaceVariant.grouped,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppIconWell(
                      icon: Icons.local_gas_station_outlined,
                      tone: AppIconWellTone.accent,
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Text(
                        'Qual o combustível do seu carro?',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  'É o que diz o que o seu carro tem e o que ele não tem. '
                  'Sem essa resposta a gente não chuta.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                AppButton(
                  label: 'Informar',
                  variant: AppButtonVariant.secondary,
                  onPressed: onFixFuel,
                  expanded: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: appGroupGap),
        ],

        for (final question in profile.questions) ...[
          ProfileQuestionCard(
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
                iconTone: AppIconWellTone.accent,
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
                    compact: true,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Text(
              'Não falta nada por aqui. Os cuidados que aparecem no app são '
              'os que fazem sentido para este carro.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Posts an answer to a profile question and refreshes what it changes.
///
/// Shared by this screen and the maintenance tab, which shows the open
/// question at its top — the one technical fact worth interrupting someone
/// for (belt or chain).
Future<void> answerProfileQuestion(
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

/// One question the server wrote, with the answers it offered.
class ProfileQuestionCard extends StatelessWidget {
  const ProfileQuestionCard({super.key, required this.question, this.onAnswer});

  final MaintenanceProfileQuestion question;
  final ValueChanged<String>? onAnswer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppSurface(
      variant: AppSurfaceVariant.grouped,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppIconWell(
                icon: Icons.help_outline,
                tone: AppIconWellTone.accent,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.s8),
                      child: Text(
                        question.prompt,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    if (question.help.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        question.help,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          // Every option the server offered, in the order it offered them
          // — including "não sei", which is a real answer and is never
          // buried.
          for (var i = 0; i < question.options.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.s8),
            AppButton(
              label: question.options[i].label,
              variant: AppButtonVariant.secondary,
              onPressed: onAnswer == null
                  ? null
                  : () => onAnswer!(question.options[i].value),
              expanded: true,
            ),
          ],
        ],
      ),
    );
  }
}
