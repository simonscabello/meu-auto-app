import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/presentation/vehicle_switcher_sheet.dart';
import 'package:meu_auto/shared/widgets/app_icon_button.dart';

/// The title of a main tab, and which car it is about.
///
/// Início is titled with the car itself. The other three tabs are titled with
/// what they are — Manutenção, Documentos, Histórico — and, as soon as the
/// account has a second car, the car's name goes under the title as the way to
/// switch. Before, only Início said which car was selected: someone who
/// switched there and went to Documentos saw an IPVA with no sign of whose it
/// was.
class VehicleContextTitle extends ConsumerWidget {
  const VehicleContextTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final vehicles = ref.watch(vehiclesProvider).valueOrNull?.vehicles ?? [];
    final selected = ref.watch(selectedVehicleProvider).valueOrNull;
    if (selected == null || vehicles.length < 2) {
      return Text(title);
    }

    return Semantics(
      button: true,
      label: '$title. ${selected.shortName}. Trocar veículo',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => VehicleSwitcherSheet.show(context),
        borderRadius: AppRadius.borderM,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      selected.shortName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.expand_more,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Início's title: the car, as the switcher.
///
/// The name is the short one ("Toyota Prius"), so the arrow that says "tap to
/// switch" is never pushed off the bar by a FIPE specification.
class VehicleSwitcherTitle extends StatelessWidget {
  const VehicleSwitcherTitle({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Trocar veículo. $name',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => VehicleSwitcherSheet.show(context),
        borderRadius: AppRadius.borderM,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: AppSpacing.s4),
              const Icon(Icons.expand_more),
            ],
          ),
        ),
      ),
    );
  }
}

/// The way into the account from any main tab.
///
/// Perfil left the navigation bar to make room for Histórico: it is visited a
/// few times a year — a name, a password, the theme, the list of cars — while
/// what happened to the car and what it cost is one of the three things the
/// product exists for, and it was reachable only from the last row of
/// Cuidados. An account button at the end of the bar is where every app the
/// owner uses already keeps it.
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      label: 'Perfil e conta',
      icon: Icons.account_circle_outlined,
      onPressed: () => context.push(AppRoutes.profile),
    );
  }
}
