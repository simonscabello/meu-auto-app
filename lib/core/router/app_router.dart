import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/router/app_shell.dart';
import 'package:meu_auto/core/router/auth_redirect.dart';
import 'package:meu_auto/core/router/password_reset_link.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';
import 'package:meu_auto/features/auth/presentation/login_screen.dart';
import 'package:meu_auto/features/auth/presentation/password_reset_confirm_screen.dart';
import 'package:meu_auto/features/auth/presentation/password_reset_request_screen.dart';
import 'package:meu_auto/features/auth/presentation/register_screen.dart';
import 'package:meu_auto/features/auth/presentation/splash_screen.dart';
import 'package:meu_auto/features/costs/presentation/costs_screen.dart';
import 'package:meu_auto/features/home/presentation/home_screen.dart';
import 'package:meu_auto/features/maintenance/presentation/cuidados_screen.dart';
import 'package:meu_auto/features/maintenance/presentation/plan_detail_screen.dart';
import 'package:meu_auto/features/maintenance/presentation/vehicle_profile_screen.dart';
import 'package:meu_auto/features/profile/presentation/delete_account_screen.dart';
import 'package:meu_auto/features/profile/presentation/profile_screen.dart';
import 'package:meu_auto/features/timeline/presentation/timeline_screen.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_detail_screen.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_form_screen.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_list_screen.dart';
import 'package:meu_auto/features/odometer/presentation/odometer_history_screen.dart';
import 'package:meu_auto/features/onboarding/presentation/calibrar_flow.dart';
import 'package:meu_auto/features/vehicle/application/vehicles_provider.dart';
import 'package:meu_auto/features/vehicle/presentation/vehicle_detail_screen.dart';
import 'package:meu_auto/features/vehicle/presentation/vehicle_form_screen.dart';
import 'package:meu_auto/features/vehicle/presentation/vehicle_list_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<AsyncValue<AuthStatus>>(authControllerProvider, (_, _) {
    refresh.value++;
  });
  ref.listen<AsyncValue<VehicleListState>>(vehiclesProvider, (_, _) {
    refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final deepLink = rewritePasswordResetDeepLink(state.uri);
      if (deepLink != null) {
        return deepLink;
      }
      final vehicles = ref.read(vehiclesProvider);
      final data = vehicles.value;
      bool? hasVehicles;
      if (data != null && data.available) {
        hasVehicles = data.vehicles.isNotEmpty;
      }
      return authRedirect(
        status: authStatusOf(ref.read(authControllerProvider)),
        location: state.matchedLocation,
        hasVehicles: hasVehicles,
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.passwordReset,
        builder: (context, state) => const PasswordResetRequestScreen(),
      ),
      GoRoute(
        path: AppRoutes.passwordResetConfirm,
        builder: (context, state) => PasswordResetConfirmScreen(
          token: passwordResetTokenOf(state.uri) ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.deleteAccount,
        builder: (context, state) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: AppRoutes.odometer,
        builder: (context, state) {
          // Scoped to the selected vehicle rather than taking an id in the
          // path: every screen inside the shell is about the current car, and
          // a second source of truth for "which vehicle" is a bug waiting.
          final vehicle = ref.read(selectedVehicleProvider).value;
          if (vehicle == null) {
            return const SizedBox.shrink();
          }
          return OdometerHistoryScreen(vehicleId: vehicle.id);
        },
      ),
      GoRoute(
        path: AppRoutes.costs,
        builder: (context, state) {
          final vehicle = ref.read(selectedVehicleProvider).value;
          if (vehicle == null) {
            return const SizedBox.shrink();
          }
          return CostsScreen(vehicleId: vehicle.id);
        },
      ),
      GoRoute(
        path: '/obrigacoes/:obligationId',
        // Prompt 17 replaces this with the obligation detail. Until that
        // screen exists, the Cuidados tab is the only place prazos appear.
        redirect: (context, state) => AppRoutes.care,
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.vehicleProfile,
        builder: (context, state) => const VehicleProfileScreen(),
      ),
      GoRoute(
        path: '/planos/:planId',
        builder: (context, state) =>
            PlanDetailScreen(planId: state.pathParameters['planId']!),
      ),
      GoRoute(
        path: AppRoutes.maintenance,
        builder: (context, state) {
          final vehicle = ref.read(selectedVehicleProvider).value;
          if (vehicle == null) {
            return const SizedBox.shrink();
          }
          return MaintenanceListScreen(vehicleId: vehicle.id);
        },
        routes: [
          GoRoute(
            path: 'nova',
            builder: (context, state) {
              final vehicle = ref.read(selectedVehicleProvider).value;
              if (vehicle == null) {
                return const SizedBox.shrink();
              }
              final extra = state.extra;
              return MaintenanceFormScreen(
                vehicleId: vehicle.id,
                currentMileageKm: vehicle.currentMileageKm,
                preselectedItem: extra is MaintenanceItem ? extra : null,
                preselectedItemId: extra is String
                    ? extra
                    : state.uri.queryParameters['item'],
              );
            },
          ),
          GoRoute(
            path: ':recordId',
            builder: (context, state) => MaintenanceDetailScreen(
              recordId: state.pathParameters['recordId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/calibrar/:vehicleId',
        builder: (context, state) {
          final vehicleId = state.pathParameters['vehicleId']!;
          final vehicles = ref.read(vehiclesProvider).value?.vehicles ?? [];
          var mileageKm = 0;
          for (final vehicle in vehicles) {
            if (vehicle.id != vehicleId) continue;
            mileageKm = vehicle.currentMileageKm;
            break;
          }
          return CalibrarFlow(
            vehicleId: vehicleId,
            currentMileageKm: mileageKm,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.vehicles,
        builder: (context, state) => const VehicleListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const VehicleFormScreen(),
          ),
          GoRoute(
            path: ':vehicleId',
            builder: (context, state) => VehicleDetailScreen(
              vehicleId: state.pathParameters['vehicleId']!,
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => VehicleFormScreen(
                  vehicleId: state.pathParameters['vehicleId'],
                ),
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.care,
                builder: (context, state) => const CuidadosScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (context, state) => const TimelineScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

AuthStatus authStatusOf(AsyncValue<AuthStatus> value) {
  final current = value.value;
  if (current != null) {
    return current;
  }
  return const AuthUnknown();
}
