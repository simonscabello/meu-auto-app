import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/router/auth_redirect.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';
import 'package:meu_auto/features/auth/domain/user.dart';

void main() {
  final loggedIn = AuthLoggedIn(
    User(
      id: '11111111-1111-1111-1111-111111111111',
      name: 'Ana',
      email: 'ana@example.com',
      createdAt: DateTime.parse('2026-01-15T12:00:00Z').toLocal(),
    ),
  );

  group('unknown', () {
    test('sends any non-splash location to splash', () {
      expect(
        authRedirect(status: const AuthUnknown(), location: AppRoutes.home),
        AppRoutes.splash,
      );
      expect(
        authRedirect(status: const AuthUnknown(), location: AppRoutes.login),
        AppRoutes.splash,
      );
      expect(
        authRedirect(status: const AuthUnknown(), location: AppRoutes.register),
        AppRoutes.splash,
      );
    });

    test('lets the password-reset confirm deep link stay during bootstrap', () {
      expect(
        authRedirect(
          status: const AuthUnknown(),
          location: AppRoutes.passwordResetConfirm,
        ),
        isNull,
      );
    });

    test('stays on splash', () {
      expect(
        authRedirect(status: const AuthUnknown(), location: AppRoutes.splash),
        isNull,
      );
    });
  });

  group('logged out', () {
    test('sends a protected route to login', () {
      expect(
        authRedirect(status: const AuthLoggedOut(), location: AppRoutes.home),
        AppRoutes.login,
      );
    });

    test('sends splash to login', () {
      expect(
        authRedirect(status: const AuthLoggedOut(), location: AppRoutes.splash),
        AppRoutes.login,
      );
    });

    test('keeps public auth routes', () {
      expect(
        authRedirect(status: const AuthLoggedOut(), location: AppRoutes.login),
        isNull,
      );
      expect(
        authRedirect(
          status: const AuthLoggedOut(),
          location: AppRoutes.register,
        ),
        isNull,
      );
      expect(
        authRedirect(
          status: const AuthLoggedOut(),
          location: AppRoutes.passwordReset,
        ),
        isNull,
      );
    });

    test(
      'lets the password-reset confirm deep link through without a session',
      () {
        expect(
          authRedirect(
            status: const AuthLoggedOut(),
            location: AppRoutes.passwordResetConfirm,
          ),
          isNull,
        );
      },
    );
  });

  group('logged in', () {
    test('stays on splash while vehicles are unknown', () {
      expect(
        authRedirect(status: loggedIn, location: AppRoutes.splash),
        isNull,
      );
    });

    test('sends login to splash while vehicles are unknown', () {
      expect(
        authRedirect(status: loggedIn, location: AppRoutes.login),
        AppRoutes.splash,
      );
    });

    test('sends an account without vehicles to the first-vehicle form', () {
      expect(
        authRedirect(
          status: loggedIn,
          location: AppRoutes.home,
          hasVehicles: false,
        ),
        AppRoutes.vehicleNew,
      );
      expect(
        authRedirect(
          status: loggedIn,
          location: AppRoutes.splash,
          hasVehicles: false,
        ),
        AppRoutes.vehicleNew,
      );
    });

    test('stays on the first-vehicle form when the list is empty', () {
      expect(
        authRedirect(
          status: loggedIn,
          location: AppRoutes.vehicleNew,
          hasVehicles: false,
        ),
        isNull,
      );
    });

    test(
      'leaves login, register, splash and password-reset when it has vehicles',
      () {
        expect(
          authRedirect(
            status: loggedIn,
            location: AppRoutes.login,
            hasVehicles: true,
          ),
          AppRoutes.home,
        );
        expect(
          authRedirect(
            status: loggedIn,
            location: AppRoutes.register,
            hasVehicles: true,
          ),
          AppRoutes.home,
        );
        expect(
          authRedirect(
            status: loggedIn,
            location: AppRoutes.splash,
            hasVehicles: true,
          ),
          AppRoutes.home,
        );
        expect(
          authRedirect(
            status: loggedIn,
            location: AppRoutes.passwordReset,
            hasVehicles: true,
          ),
          AppRoutes.home,
        );
      },
    );

    test('keeps the password-reset confirm deep link even when logged in', () {
      expect(
        authRedirect(
          status: loggedIn,
          location: AppRoutes.passwordResetConfirm,
          hasVehicles: true,
        ),
        isNull,
      );
    });

    test('stays on the protected home when it has vehicles', () {
      expect(
        authRedirect(
          status: loggedIn,
          location: AppRoutes.home,
          hasVehicles: true,
        ),
        isNull,
      );
    });

    test('stays on the new-vehicle form when adding another', () {
      expect(
        authRedirect(
          status: loggedIn,
          location: AppRoutes.vehicleNew,
          hasVehicles: true,
        ),
        isNull,
      );
    });
  });
}
